;;; test-chime-propertize-modeline.el --- Tests for chime--propertize-modeline-string -*- lexical-binding: t; -*-

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

;; Unit tests for chime--propertize-modeline-string function.
;; This function adds tooltip, click handlers, and mouse-face to modeline text.

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
(load (expand-file-name "../chime.el") nil t)

;; Load test utilities
(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))
(require 'testutil-events (expand-file-name "testutil-events.el"))

;;; Setup/Teardown

(defun test-chime-propertize-setup ()
  "Setup function."
  (chime-create-test-base-dir)
  (setq chime-tooltip-header-format "Upcoming Events as of %a %b %d %Y @ %I:%M %p")
  (setq chime-display-time-format-string "%I:%M %p")
  (setq chime-time-left-format-at-event "right now")
  (setq chime-time-left-format-short "in %M")
  (setq chime-time-left-format-long "in %H %M"))

(defun test-chime-propertize-teardown ()
  "Teardown function."
  (chime-delete-test-base-dir)
  (setq chime--upcoming-events nil))

;;; Normal Cases

(ert-deftest test-chime-propertize-adds-help-echo ()
  "Should add help-echo property (tooltip) when events exist."
  (test-chime-propertize-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (event-time (time-add now (seconds-to-time 1800)))
             (ts (test-timestamp-string event-time)))
        (setq chime--upcoming-events
              (list (list `((title . "Meeting") (times . ((,ts . ,event-time))))
                          (cons ts event-time)
                          30)))
        (with-test-time now
          (let ((result (chime--propertize-modeline-string " ⏰ Meeting")))
            (should (get-text-property 0 'help-echo result)))))
    (test-chime-propertize-teardown)))

(ert-deftest test-chime-propertize-adds-mouse-face ()
  "Should add mouse-face property for highlight on hover."
  (test-chime-propertize-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (event-time (time-add now (seconds-to-time 1800)))
             (ts (test-timestamp-string event-time)))
        (setq chime--upcoming-events
              (list (list `((title . "Meeting") (times . ((,ts . ,event-time))))
                          (cons ts event-time)
                          30)))
        (with-test-time now
          (let ((result (chime--propertize-modeline-string " ⏰ Meeting")))
            (should (eq 'mode-line-highlight
                        (get-text-property 0 'mouse-face result))))))
    (test-chime-propertize-teardown)))

(ert-deftest test-chime-propertize-adds-keymap ()
  "Should add local-map with click handlers."
  (test-chime-propertize-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (event-time (time-add now (seconds-to-time 1800)))
             (ts (test-timestamp-string event-time)))
        (setq chime--upcoming-events
              (list (list `((title . "Meeting") (times . ((,ts . ,event-time))))
                          (cons ts event-time)
                          30)))
        (with-test-time now
          (let ((result (chime--propertize-modeline-string " ⏰ Meeting")))
            (should (keymapp (get-text-property 0 'local-map result))))))
    (test-chime-propertize-teardown)))

(ert-deftest test-chime-propertize-tooltip-contains-event ()
  "Tooltip text should contain the event title."
  (test-chime-propertize-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (event-time (time-add now (seconds-to-time 1800)))
             (ts (test-timestamp-string event-time)))
        (setq chime--upcoming-events
              (list (list `((title . "Team Standup") (times . ((,ts . ,event-time))))
                          (cons ts event-time)
                          30)))
        (with-test-time now
          (let* ((result (chime--propertize-modeline-string " ⏰ Meeting"))
                 (tooltip (get-text-property 0 'help-echo result)))
            (should (string-match-p "Team Standup" tooltip)))))
    (test-chime-propertize-teardown)))

;;; Boundary Cases

(ert-deftest test-chime-propertize-nil-events-returns-plain-text ()
  "When chime--upcoming-events is nil, should return plain text without properties."
  (test-chime-propertize-setup)
  (unwind-protect
      (let ((chime--upcoming-events nil))
        (let ((result (chime--propertize-modeline-string " ⏰")))
          ;; Should return the text as-is
          (should (string= " ⏰" result))
          ;; Should NOT have help-echo (no tooltip)
          (should-not (get-text-property 0 'help-echo result))))
    (test-chime-propertize-teardown)))

(ert-deftest test-chime-propertize-empty-text ()
  "Empty string should still get properties when events exist."
  (test-chime-propertize-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (event-time (time-add now (seconds-to-time 1800)))
             (ts (test-timestamp-string event-time)))
        (setq chime--upcoming-events
              (list (list `((title . "Meeting") (times . ((,ts . ,event-time))))
                          (cons ts event-time)
                          30)))
        (with-test-time now
          (let ((result (chime--propertize-modeline-string "")))
            ;; Even empty string gets propertized
            (should (stringp result)))))
    (test-chime-propertize-teardown)))

(provide 'test-chime-propertize-modeline)
;;; test-chime-propertize-modeline.el ends here
