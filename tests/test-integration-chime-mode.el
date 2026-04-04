;;; test-integration-chime-mode.el --- Integration tests for chime-mode activation -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

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

;; Integration tests for chime-mode activation and deactivation.
;; Tests the minor mode lifecycle: enabling adds modeline display,
;; disabling removes it and cleans up state.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;; Load test utilities
(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))
(require 'testutil-events (expand-file-name "testutil-events.el"))

;;; Tests

(ert-deftest test-integration-chime-mode-enable-adds-to-global-mode-string ()
  "Enabling chime-mode should add chime-modeline-string to global-mode-string."
  (let ((chime-enable-modeline t)
        (chime-modeline-lookahead-minutes 60))
    (unwind-protect
        (progn
          (chime-mode 1)
          (should (memq 'chime-modeline-string global-mode-string)))
      (chime-mode -1))))

(ert-deftest test-integration-chime-mode-disable-removes-from-global-mode-string ()
  "Disabling chime-mode should remove chime-modeline-string from global-mode-string
and set it to nil."
  (let ((chime-enable-modeline t)
        (chime-modeline-lookahead-minutes 60))
    (chime-mode 1)
    (chime-mode -1)
    (should-not (memq 'chime-modeline-string global-mode-string))
    (should (null chime-modeline-string))))

(ert-deftest test-integration-chime-mode-disable-nils-timer ()
  "Disabling chime-mode should set chime--timer to nil."
  (let ((chime-enable-modeline t)
        (chime-modeline-lookahead-minutes 60))
    (chime-mode 1)
    ;; Timer should exist after enable
    (should chime--timer)
    (chime-mode -1)
    ;; Timer should be nil after disable
    (should (null chime--timer))))

(ert-deftest test-integration-chime-mode-enable-sets-modeline-string-immediately ()
  "Enabling chime-mode should set chime-modeline-string to a non-nil value
immediately, before the first async check completes."
  (let ((chime-enable-modeline t)
        (chime-modeline-lookahead-minutes 120)
        (chime-modeline-no-events-text " ⏰"))
    (unwind-protect
        (progn
          (chime-mode 1)
          ;; Should be non-nil right away, not after startup delay
          (should chime-modeline-string)
          (should (stringp chime-modeline-string)))
      (chime-mode -1))))

(ert-deftest test-integration-chime-mode-enable-immediate-string-has-tooltip ()
  "The immediate modeline string should have a help-echo tooltip."
  (let ((chime-enable-modeline t)
        (chime-modeline-lookahead-minutes 120)
        (chime-modeline-no-events-text " ⏰"))
    (unwind-protect
        (progn
          (chime-mode 1)
          (should (get-text-property 0 'help-echo chime-modeline-string)))
      (chime-mode -1))))

(ert-deftest test-integration-chime-mode-validation-failure-keeps-icon-visible ()
  "When validation fails, modeline should still show the icon with error info
in the tooltip, not go blank."
  (let ((chime-enable-modeline t)
        (chime-modeline-lookahead-minutes 120)
        (chime-modeline-no-events-text " ⏰")
        (org-agenda-files nil)
        (chime--validation-done nil)
        (chime--validation-retry-count 0)
        (chime-validation-max-retries 0))
    (unwind-protect
        (progn
          (chime-mode 1)
          ;; Force a check that will fail validation
          (chime-check)
          ;; Icon should still be visible, not nil
          (should chime-modeline-string)
          (should (stringp chime-modeline-string)))
      (chime-mode -1))))

(provide 'test-integration-chime-mode)
;;; test-integration-chime-mode.el ends here
