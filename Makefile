# Makefile for chime.el
# Delegates all test targets to tests/Makefile.
# Run 'make help' for available commands.

TEST_DIR = tests

.PHONY: help test test-unit test-integration test-file test-one test-name \
        count list validate lint check-deps clean

help:
	@$(MAKE) -C $(TEST_DIR) help

test:
	@$(MAKE) -C $(TEST_DIR) test

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
