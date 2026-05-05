# Makefile for chime.el test suite
# Usage:
#   make test              - Run all tests (excluding :slow tagged)
#   make test-all          - Run every test, including :slow tagged
#   make test-file FILE=overdue - Run tests in one file
#   make test-one TEST=name     - Run one specific test
#   make test-unit         - Run unit tests only
#   make test-integration  - Run integration tests only
#   make clean             - Remove byte-compiled files

# Configuration
EASK ?= eask

# eask treats the CWD as its workspace and reads .eask/ from there.  All
# eask invocations must run from project root so the project's .eask/
# is picked up.  The (cd "tests/") --eval restores Emacs default-directory
# so test files' relative paths (../chime.el, test-bootstrap.el) resolve
# the way they did under the old plain-emacs setup.
PROJECT_ROOT := $(abspath ..)
EMACS_BATCH = cd $(PROJECT_ROOT) && $(EASK) emacs --batch --eval '(cd "tests/")'

# Include local overrides if present (per-machine knobs, not committed)
-include makefile-local

# Test files
ALL_TESTS = $(filter-out test-bootstrap.el,$(wildcard test-*.el))
UNIT_TESTS = $(filter-out test-integration-%.el,$(ALL_TESTS))
INTEGRATION_TESTS = $(wildcard test-integration-*.el)

# ERT selector that excludes tests tagged :slow.  Applied to default
# test runs so a slow integration suite doesn't dominate the fast
# feedback path.  test-all runs everything; test-one and test-name
# honor the user-supplied pattern verbatim.
ERT_FAST_SELECTOR = (ert-run-tests-batch-and-exit '(not (tag :slow)))

# Colors for output (if terminal supports it)
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
NC = \033[0m

.PHONY: all test test-all test-file test-one test-name test-unit test-integration validate lint clean help check-deps

all: test

# Verify eask + installed deps are available
check-deps:
	@if ! command -v $(EASK) >/dev/null 2>&1; then \
		printf "$(RED)Error: eask not found on PATH$(NC)\n"; \
		echo "Install:  npm install -g @emacs-eask/cli"; \
		echo "    or:   https://emacs-eask.github.io/Getting-Started/Install-Eask/"; \
		exit 1; \
	fi
	@if [ ! -d $(PROJECT_ROOT)/.eask ]; then \
		printf "$(YELLOW)Warning: .eask not found — run 'make setup' from project root$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ eask available, deps installed$(NC)\n"

# Run all tests (excluding :slow)
test: check-deps
	@printf "$(YELLOW)Running all tests ($(words $(ALL_TESTS)) files, excluding :slow)...$(NC)\n"
	@$(MAKE) --no-print-directory test-unit
	@$(MAKE) --no-print-directory test-integration
	@printf "$(GREEN)[✓] All tests complete$(NC)\n"

# Run every test, including :slow tagged
test-all: check-deps
	@printf "$(YELLOW)Running all tests including :slow ($(words $(ALL_TESTS)) files)...$(NC)\n"
	@failed=0; \
	for testfile in $(ALL_TESTS); do \
		echo "  Testing $$testfile..."; \
		$(EMACS_BATCH) -l ert -l "$$testfile" \
			--eval '(ert-run-tests-batch-and-exit t)' || failed=$$((failed + 1)); \
	done; \
	if [ $$failed -eq 0 ]; then \
		printf "$(GREEN)[✓] All tests passed$(NC)\n"; \
	else \
		printf "$(RED)[✗] $$failed test file(s) failed$(NC)\n"; \
		exit 1; \
	fi

# Run tests in one file
test-file: check-deps
ifndef FILE
	@printf "$(RED)Error: FILE not specified$(NC)\n"
	@echo "Usage: make test-file FILE=overdue"
	@echo "       make test-file FILE=test-chime-overdue-todos.el"
	@exit 1
endif
	@TESTFILE=$$(find . -maxdepth 1 -name "*$(FILE)*.el" -type f | head -1 | sed 's|^\./||'); \
	if [ -z "$$TESTFILE" ]; then \
		printf "$(RED)Error: No test file matching '$(FILE)' found$(NC)\n"; \
		exit 1; \
	fi; \
	printf "$(YELLOW)Running tests in $$TESTFILE...$(NC)\n"; \
	$(EMACS_BATCH) -l ert -l "$$TESTFILE" \
		--eval "$(ERT_FAST_SELECTOR)" 2>&1 | tee $(PROJECT_ROOT)/tests/test-file-output.log; \
	if [ $$? -eq 0 ]; then \
		printf "$(GREEN)✓ All tests in $$TESTFILE passed!$(NC)\n"; \
	else \
		printf "$(RED)✗ Some tests failed.$(NC)\n"; \
		exit 1; \
	fi

# Run one specific test (fuzzy match by name)
test-one: check-deps
ifndef TEST
	@printf "$(RED)Error: TEST not specified$(NC)\n"
	@echo "Usage: make test-one TEST=pilot"
	@echo "       make test-one TEST=test-overdue-has-passed-time-today-all-day"
	@exit 1
endif
	@printf "$(YELLOW)Searching for test matching '$(TEST)'...$(NC)\n"
	@TESTFILE=$$(grep -l "ert-deftest.*$(TEST)" test-*.el 2>/dev/null | head -1); \
	if [ -z "$$TESTFILE" ]; then \
		printf "$(RED)Error: No test matching '$(TEST)' found$(NC)\n"; \
		exit 1; \
	fi; \
	TESTNAME=$$(grep "ert-deftest.*$(TEST)" "$$TESTFILE" | sed 's/^(ert-deftest \([^ ]*\).*/\1/' | head -1); \
	printf "$(YELLOW)Running test '$$TESTNAME' in $$TESTFILE...$(NC)\n"; \
	$(EMACS_BATCH) -l ert -l "$$TESTFILE" \
		--eval "(ert-run-tests-batch-and-exit \"$$TESTNAME\")" 2>&1; \
	if [ $$? -eq 0 ]; then \
		printf "$(GREEN)✓ Test $$TESTNAME passed!$(NC)\n"; \
	else \
		printf "$(RED)✗ Test $$TESTNAME failed.$(NC)\n"; \
		exit 1; \
	fi

# Run only unit tests (excluding :slow)
test-unit: check-deps
	@printf "$(YELLOW)Running unit tests ($(words $(UNIT_TESTS)) files, excluding :slow)...$(NC)\n"
	@failed=0; \
	for testfile in $(UNIT_TESTS); do \
		echo "  Testing $$testfile..."; \
		$(EMACS_BATCH) -l ert -l "$$testfile" \
			--eval "$(ERT_FAST_SELECTOR)" || failed=$$((failed + 1)); \
	done; \
	if [ $$failed -eq 0 ]; then \
		printf "$(GREEN)[✓] All unit tests passed$(NC)\n"; \
	else \
		printf "$(RED)[✗] $$failed unit test file(s) failed$(NC)\n"; \
		exit 1; \
	fi

# Run only integration tests (excluding :slow)
test-integration: check-deps
	@printf "$(YELLOW)Running integration tests ($(words $(INTEGRATION_TESTS)) files, excluding :slow)...$(NC)\n"
	@failed=0; \
	for testfile in $(INTEGRATION_TESTS); do \
		echo "  Testing $$testfile..."; \
		$(EMACS_BATCH) -l ert -l "$$testfile" \
			--eval "$(ERT_FAST_SELECTOR)" || failed=$$((failed + 1)); \
	done; \
	if [ $$failed -eq 0 ]; then \
		printf "$(GREEN)[✓] All integration tests passed$(NC)\n"; \
	else \
		printf "$(RED)[✗] $$failed integration test file(s) failed$(NC)\n"; \
		exit 1; \
	fi

# Run tests matching a name pattern (ERT selector)
test-name: check-deps
ifndef TEST
	@printf "$(RED)Error: TEST not specified$(NC)\n"
	@echo "Usage: make test-name TEST=test-chime-check-early-return"
	@echo "       make test-name TEST='test-chime-check-*'"
	@exit 1
endif
	@printf "$(YELLOW)Running tests matching pattern: $(TEST)...$(NC)\n"
	@$(EMACS_BATCH) -l ert \
		--eval "(dolist (f (directory-files \".\" t \"^test-.*\\\\.el$$\")) (load f))" \
		--eval '(ert-run-tests-batch-and-exit "$(TEST)")'

# Count tests
count:
	@echo "Test file inventory:"
	@for f in $(ALL_TESTS); do \
		count=$$(grep -c "^(ert-deftest" "$$f" 2>/dev/null || echo 0); \
		printf "%3d tests - %s\n" "$$count" "$$f"; \
	done | sort -rn
	@total=$$(find . -name "test-*.el" -exec grep -c "^(ert-deftest" {} \; | awk '{sum+=$$1} END {print sum}'); \
	printf "$(GREEN)Total: $$total tests across $(words $(ALL_TESTS)) files$(NC)\n"

# List all available tests
list:
	@echo "Available tests:"
	@grep -h "^(ert-deftest" test-*.el | sed 's/^(ert-deftest \([^ ]*\).*/  \1/' | sort

# Validate Emacs Lisp syntax (parens balance — no deps needed)
validate:
	@printf "$(YELLOW)Validating Emacs Lisp syntax...$(NC)\n"
	@failed=0; \
	total=0; \
	for file in ../chime.el test-*.el testutil-*.el; do \
		if [ -f "$$file" ] && [ ! -d "$$file" ]; then \
			total=$$((total + 1)); \
			output=$$(emacs --batch -Q --eval "(progn \
				(setq byte-compile-error-on-warn nil) \
				(find-file \"$$file\") \
				(condition-case err \
					(progn \
						(check-parens) \
						(message \"✓ $$file - parentheses balanced\")) \
					(error \
						(message \"✗ $$file: %s\" (error-message-string err)) \
						(kill-emacs 1))))" 2>&1 | grep -E '(✓|✗)'); \
			if [ $$? -eq 0 ]; then \
				printf "$(GREEN)$$output$(NC)\n"; \
			else \
				printf "$(RED)$$output$(NC)\n"; \
				failed=$$((failed + 1)); \
			fi; \
		fi; \
	done; \
	if [ $$failed -eq 0 ]; then \
		printf "$(GREEN)✓ All $$total files validated successfully$(NC)\n"; \
	else \
		printf "$(RED)✗ $$failed of $$total files failed validation$(NC)\n"; \
		exit 1; \
	fi

# Comprehensive linting with elisp-lint (via eask-installed dev dep).
# Scope: package files only.  Tests don't pass package-lint (they aren't
# standalone packages).
# Validators disabled and why:
# - checkdoc: covered by `eask lint checkdoc' as its own MELPA-prep step.
# - package-lint: covered by `eask lint package' as its own step; running it
#   here re-flags the auxiliary files because they no longer carry their own
#   Package-Requires.
# - indent-character: project uses spaces (per `.claude/rules/elisp.md');
#   the validator defaults to requiring tabs.
# - fill-column: project allows up to 80 columns; the validator defaults to 70.
# - indent: produces false positives on dash threading macros (`->', `->>')
#   whose indentation rule the validator doesn't know.  Real indent bugs
#   are caught by check-parens and review.
lint: check-deps
	@printf "$(YELLOW)Running elisp-lint...$(NC)\n"
	@$(EMACS_BATCH) \
		-l $(PROJECT_ROOT)/chime.el \
		--eval "(require 'elisp-lint)" \
		-f elisp-lint-files-batch \
		--no-checkdoc \
		--no-package-lint \
		--no-indent-character \
		--no-fill-column \
		--no-indent \
		$(PROJECT_ROOT)/chime.el \
		$(PROJECT_ROOT)/chime-debug.el \
		$(PROJECT_ROOT)/chime-org-contacts.el 2>&1; \
	if [ $$? -eq 0 ]; then \
		printf "$(GREEN)✓ Linting completed successfully$(NC)\n"; \
	else \
		printf "$(RED)✗ Linting found issues (see above)$(NC)\n"; \
		exit 1; \
	fi

# Clean byte-compiled files
clean:
	@printf "$(YELLOW)Cleaning byte-compiled files...$(NC)\n"
	@rm -f *.elc ../*.elc
	@rm -f test-output.log test-file-output.log test-unit-output.log test-integration-output.log
	@printf "$(GREEN)✓ Cleaned$(NC)\n"

# Show help
help:
	@echo "Chime Test Suite Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make test                      - Run all tests, excluding :slow"
	@echo "  make test-all                  - Run all tests including :slow"
	@echo "  make test-unit                 - Run unit tests only (excluding :slow)"
	@echo "  make test-integration          - Run integration tests only (excluding :slow)"
	@echo "  make test-file FILE=overdue    - Run tests in one file (fuzzy match)"
	@echo "  make test-one TEST=pilot       - Run one specific test (fuzzy match)"
	@echo "  make test-name TEST=pattern    - Run tests matching ERT name pattern"
	@echo "  make validate                  - Validate Emacs Lisp syntax (parens balance)"
	@echo "  make lint                      - Comprehensive linting with elisp-lint"
	@echo "  make count                     - Count tests per file"
	@echo "  make list                      - List all test names"
	@echo "  make clean                     - Remove byte-compiled files and logs"
	@echo "  make check-deps                - Verify eask + installed deps"
	@echo "  make help                      - Show this help message"
	@echo ""
	@echo "Project-root targets (run from project root):"
	@echo "  make setup                     - Install all deps via eask"
	@echo "  make compile                   - Byte-compile chime.el"
	@echo "  make coverage                  - Generate simplecov JSON via undercover"
	@echo ""
	@echo "Tagging tests as :slow:"
	@echo "  (ert-deftest test-foo () :tags '(:slow) ...) — excluded by default"
	@echo "  Run with 'make test-all' to include them."
	@echo ""
	@echo "Environment variables:"
	@echo "  EASK       - eask executable (default: eask)"
