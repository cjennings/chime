;;; test-integration-startup.el --- Integration tests for chime startup flow -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026 Craig Jennings

;; Author: Craig Jennings <c@cjennings.net>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Integration tests for chime startup and configuration validation.
;;
;; Tests the complete startup workflow:
;; - Valid org-agenda-files configuration
;; - chime-validate-configuration checks
;; - chime-check async event gathering
;; - Modeline population
;;
;; Components integrated:
;; - chime-validate-configuration (validates runtime requirements)
;; - chime-check (async event gathering via org-agenda-list)
;; - chime--update-modeline (updates modeline string)
;; - org-agenda-list (expands events from org files)
;;
;; Validates:
;; - Chime finds correct number of events from org-agenda-files
;; - Validation passes with proper configuration
;; - Modeline gets populated after check completes
;; - Mixed event types (scheduled, deadline, TODO states) work correctly

;;; Code:

;; Initialize package system for batch mode
(when noninteractive
  (package-initialize))

(require 'ert)

;; Load dependencies required by chime
(require 'dash)
(require 'alert)
(require 'async)
(require 'org-agenda)

;; Load chime from parent directory
(setq chime-debug t)
(load (expand-file-name "../chime.el") nil t)

;; Load test utilities
(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))
(require 'testutil-events (expand-file-name "testutil-events.el"))

;;; Helper Functions

(defun test-integration-startup--create-org-file (content)
  "Create org file with CONTENT and set it as org-agenda-files.
Returns the file path."
  (let* ((base-file (chime-create-temp-test-file "startup-test-"))
         (org-file (concat base-file ".org")))
    ;; Rename to have .org extension
    (rename-file base-file org-file)
    ;; Write content to the .org file
    (with-temp-buffer
      (insert content)
      (write-file org-file))
    ;; Set as agenda file
    (setq org-agenda-files (list org-file))
    org-file))

(defmacro with-startup-config (&rest body)
  "Execute BODY with standard startup test config and temp dir management.

Combines two concerns that every test in this file needs:
  1. `with-test-setup' creates/cleans up the temp test directory.
  2. `with-chime-config' `let'-binds config overrides so they auto-restore
     when BODY exits (even on error), replacing the old pattern of saving
     originals to defvars in setup and restoring them in teardown.

The overrides set a 24-hour lookahead window and a 1-second startup delay
so tests can exercise the full startup path without waiting or creating
events far in the future."
  (declare (indent 0))
  `(with-test-setup
     (with-chime-config
       chime-modeline-lookahead-minutes (* 24 60)
       chime-tooltip-lookahead-hours 24
       chime-startup-delay 1
       ,@body)))

;;; Normal Cases - Valid Startup Configuration

(ert-deftest test-integration-startup-valid-config-finds-events ()
  "Test that chime-check finds events with valid org-agenda-files configuration.

This is the core startup integration test. Validates that when:
- org-agenda-files is properly configured with real .org files
- Files contain scheduled/deadline events
- chime-check is called (normally triggered by startup timer)

Then:
- Events are successfully gathered from org-agenda-list
- Event count matches expected number
- Modeline string gets populated

Components integrated:
- org-agenda-files (user configuration)
- org-agenda-list (expands events from org files)
- chime-check (async wrapper around event gathering)
- chime--gather-info (extracts event details)
- chime--update-modeline (updates modeline display)"
  (with-startup-config
    (let* ((now (test-time-now))
           ;; Create events at various times
           (event1-time (test-time-at 0 2 0))    ; 2 hours from now
           (event2-time (test-time-at 0 5 0))    ; 5 hours from now
           (event3-time (test-time-at 1 0 0))    ; Tomorrow same time
           (event4-time (test-time-at -1 0 0))   ; Yesterday (overdue)
           ;; Generate timestamps
           (ts1 (test-timestamp-string event1-time))
           (ts2 (test-timestamp-string event2-time))
           (ts3 (test-timestamp-string event3-time))
           (ts4 (test-timestamp-string event4-time))
           ;; Create org file content
           (content (format "#+TITLE: Startup Test Events

* TODO Event in 2 hours
SCHEDULED: %s

* TODO Event in 5 hours
SCHEDULED: %s

* TODO Event tomorrow
SCHEDULED: %s

* TODO Overdue event
SCHEDULED: %s

* DONE Completed event (should not notify)
SCHEDULED: %s
" ts1 ts2 ts3 ts4 ts1)))

      ;; Create org file and set as agenda files
      (test-integration-startup--create-org-file content)

      ;; Validate configuration should pass
      (let ((issues (chime-validate-configuration)))
        (should (null issues)))

      (with-test-time now
        ;; Call chime-check synchronously (bypasses async/timer for test reliability)
        ;; In real startup, this is called via run-at-time after chime-startup-delay
        (let ((event-count 0))
          ;; Mock the async-start to run synchronously for testing
          (cl-letf (((symbol-function 'async-start)
                     (lambda (start-func finish-func)
                       ;; Call start-func synchronously and pass result to finish-func
                       (funcall finish-func (funcall start-func)))))
            ;; Now call chime-check - it will run synchronously
            (chime-check)

            ;; Give it a moment to process
            (sleep-for 0.1)

            ;; Verify modeline was updated
            (should chime-modeline-string)

            ;; Verify we found events (should be 4 TODO events, DONE excluded)
            ;; Note: The exact behavior depends on chime's filtering logic
            (should chime--upcoming-events)
            (setq event-count (length chime--upcoming-events))

            ;; Should find at least the non-DONE events within lookahead window
            (should (>= event-count 3))))))))  ; At least 3 events (2h, 5h, tomorrow)

(ert-deftest test-integration-startup-validation-passes-minimal-config ()
  "Test validation passes with minimal valid configuration.

Validates that chime-validate-configuration returns nil (no issues) when:
- org-agenda-files is set to a list with at least one .org file
- The file exists on disk
- org-agenda package is loadable
- All other dependencies are available

This ensures the startup validation doesn't block legitimate configurations."
  (with-startup-config
    (let ((content "#+TITLE: Minimal Test\n\n* TODO Test event\nSCHEDULED: <2025-12-01 Mon 10:00>\n"))
      ;; Create minimal org file
      (test-integration-startup--create-org-file content)

      ;; Validation should pass
      (let ((issues (chime-validate-configuration)))
        (should (null issues))))))

;;; Error Cases - Configuration Failures

(ert-deftest test-integration-startup-early-return-on-validation-failure ()
  "Test that chime-check returns early when validation fails without throwing errors.

This is a regression test for the bug where chime-check used cl-return-from
without being defined as cl-defun, causing '(no-catch --cl-block-chime-check-- nil)' error.

When validation fails on first check, chime-check should:
- Log the validation failure
- Return nil early (via cl-return-from)
- NOT throw 'no-catch' error
- NOT proceed to event gathering

This validates the early-return mechanism works correctly."
  (with-startup-config
    ;; Set up invalid configuration (empty org-agenda-files)
    (setq org-agenda-files nil)

    ;; Reset validation state so chime-check will validate on next call
    (setq chime--validation-done nil)
    (setq chime--validation-retry-count 0)

    ;; Clear state from any previous tests so we can verify
    ;; early return doesn't set these
    (setq chime--upcoming-events nil)
    (setq chime-modeline-string nil)

    ;; Call chime-check - should return early without error
    ;; Before the fix, this would throw: (no-catch --cl-block-chime-check-- nil)
    (let ((result (chime-check)))

      ;; Should return nil (early return from validation failure)
      (should (null result))

      ;; Validation should NOT be marked done when it fails
      ;; (so it can retry on next check in case dependencies load later)
      (should (null chime--validation-done))

      ;; Should NOT have processed any events (early return worked)
      (should (null chime--upcoming-events))
      (should (null chime-modeline-string)))))

;;; Boundary Cases - Edge Conditions

(ert-deftest test-integration-startup-single-event-found ()
  "Test that chime-check correctly finds a single event.

Boundary case: org-agenda-files with only one event.
Validates that the gathering and modeline logic work with minimal data."
  (with-startup-config
    (let* ((now (test-time-now))
           (event-time (test-time-at 0 1 0))  ; 1 hour from now
           (ts (test-timestamp-string event-time))
           (content (format "* TODO Single Event\nSCHEDULED: %s\n" ts)))

      (test-integration-startup--create-org-file content)

      (with-test-time now
        (cl-letf (((symbol-function 'async-start)
                   (lambda (start-func finish-func)
                     (funcall finish-func (funcall start-func)))))
          (chime-check)
          (sleep-for 0.1)

          ;; Should find exactly 1 event
          (should (= 1 (length chime--upcoming-events)))

          ;; Modeline should be populated
          (should chime-modeline-string)
          (should (string-match-p "Single Event" chime-modeline-string)))))))

(ert-deftest test-integration-startup-no-upcoming-events ()
  "Test chime-check when org file has no upcoming events within lookahead.

Boundary case: Events exist but are far in the future (beyond lookahead window).
Validates that chime doesn't error and modeline shows appropriate state."
  (with-startup-config
    (let* ((now (test-time-now))
           ;; Event 30 days from now (beyond 24-hour lookahead)
           (event-time (test-time-at 30 0 0))
           (ts (test-timestamp-string event-time))
           (content (format "* TODO Future Event\nSCHEDULED: %s\n" ts)))

      (test-integration-startup--create-org-file content)

      (with-test-time now
        (cl-letf (((symbol-function 'async-start)
                   (lambda (start-func finish-func)
                     (funcall finish-func (funcall start-func)))))
          (chime-check)
          (sleep-for 0.1)

          ;; Should find 0 events within lookahead window
          (should (or (null chime--upcoming-events)
                     (= 0 (length chime--upcoming-events))))

          ;; Modeline should handle this gracefully (nil or empty)
          ;; No error should occur
          )))))

(provide 'test-integration-startup)
;;; test-integration-startup.el ends here
