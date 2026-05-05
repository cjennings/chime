# Makefile for chime.el
# Test targets delegate to tests/Makefile.
# setup / compile / coverage operate at project root.
# Run 'make help' for available commands.

EASK ?= eask
EMACS_BATCH = $(EASK) emacs --batch
# Coverage / test loops need default-directory = tests/ so test files'
# relative paths (../chime.el, sibling test files) resolve as they do
# under tests/Makefile.
EMACS_BATCH_TESTS = $(EASK) emacs --batch --eval '(cd "tests/")'

TEST_DIR = tests
SOURCE_FILE = chime.el

# Coverage configuration
COVERAGE_DIR = .coverage
COVERAGE_FILE = $(COVERAGE_DIR)/simplecov.json

# Unit-test files (used by coverage loop, mirroring tests/Makefile)
UNIT_TESTS = $(filter-out $(TEST_DIR)/test-bootstrap.el $(TEST_DIR)/test-integration-%.el, \
                          $(wildcard $(TEST_DIR)/test-*.el))

# Include local overrides if present (per-machine knobs, not committed)
-include makefile-local

.PHONY: help test test-all test-unit test-integration test-file test-one test-name \
        count list validate lint check-deps clean \
        setup compile coverage coverage-clean

help:
	@$(MAKE) -C $(TEST_DIR) help

# Test target delegations
test:
	@$(MAKE) -C $(TEST_DIR) test

test-all:
	@$(MAKE) -C $(TEST_DIR) test-all

test-unit:
	@$(MAKE) -C $(TEST_DIR) test-unit

test-integration:
	@$(MAKE) -C $(TEST_DIR) test-integration

test-file:
	@$(MAKE) -C $(TEST_DIR) test-file FILE="$(FILE)"

test-one:
	@$(MAKE) -C $(TEST_DIR) test-one TEST="$(TEST)"

test-name:
	@$(MAKE) -C $(TEST_DIR) test-name TEST="$(TEST)"

count:
	@$(MAKE) -C $(TEST_DIR) count

list:
	@$(MAKE) -C $(TEST_DIR) list

validate:
	@$(MAKE) -C $(TEST_DIR) validate

lint:
	@$(MAKE) -C $(TEST_DIR) lint

check-deps:
	@$(MAKE) -C $(TEST_DIR) check-deps

clean:
	@$(MAKE) -C $(TEST_DIR) clean
	@rm -rf $(COVERAGE_DIR)

#
# Project-root targets — operate on chime.el at root level
#

# Install runtime + development dependencies via eask
setup:
	@if ! command -v $(EASK) >/dev/null 2>&1; then \
		echo "[✗] eask not found on PATH"; \
		echo "    Install: npm install -g @emacs-eask/cli"; \
		echo "    Or:      https://emacs-eask.github.io/Getting-Started/Install-Eask/"; \
		exit 1; \
	fi
	@echo "[i] Installing dependencies via eask..."
	@$(EASK) install-deps --dev
	@echo "[✓] Dependencies installed in .eask/"

# Byte-compile chime.el — surfaces free-variable / unused-let / suspicious-call
# warnings that checkdoc and elisp-lint don't catch.  byte-compile-error-on-warn
# is t so any warning fails the build; the backlog is clear and we want to keep
# it that way.
compile:
	@echo "[i] Byte-compiling $(SOURCE_FILE)..."
	@$(EMACS_BATCH) \
		--eval "(progn \
		  (setq byte-compile-error-on-warn t) \
		  (batch-byte-compile))" $(SOURCE_FILE)
	@echo "[✓] Compilation complete"

#
# Coverage (undercover + simplecov JSON)
#
# Each unit-test file runs in its own Emacs process (matching test-unit);
# tests/run-coverage-file.el instruments chime.el before the source is
# loaded, and undercover merges per-file results into a single simplecov JSON.

coverage: coverage-clean $(COVERAGE_DIR)
	@echo "[i] Cleaning .elc files so undercover can instrument source..."
	@find . -name "*.elc" -delete
	@echo "[i] Running coverage across $(words $(UNIT_TESTS)) unit-test file(s)..."
	@echo "    (slower than 'make test-unit' — each file runs in its own Emacs)"
	@failed=0; \
	for test in $(UNIT_TESTS); do \
		echo "  Coverage: $$test..."; \
		testfile=$$(basename $$test); \
		$(EMACS_BATCH_TESTS) \
			-l ert \
			-l run-coverage-file.el \
			-l ../$(SOURCE_FILE) \
			-l $$testfile \
			--eval "(ert-run-tests-batch-and-exit '(not (tag :slow)))" || failed=$$((failed + 1)); \
	done; \
	if [ $$failed -gt 0 ]; then \
		echo "[!] $$failed test file(s) failed during coverage run"; \
		exit 1; \
	fi
	@if [ -f $(COVERAGE_FILE) ]; then \
		echo "[✓] Coverage report: $(COVERAGE_FILE) ($$(du -h $(COVERAGE_FILE) | cut -f1))"; \
	else \
		echo "[!] No coverage file produced; check that undercover is installed"; \
		exit 1; \
	fi

coverage-clean:
	@rm -f $(COVERAGE_FILE)

$(COVERAGE_DIR):
	@mkdir -p $(COVERAGE_DIR)
