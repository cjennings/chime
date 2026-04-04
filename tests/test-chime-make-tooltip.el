;;; test-chime-make-tooltip.el --- Tests for tooltip generation functions -*- lexical-binding: t; -*-

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

;; Unit tests for tooltip generation functions:
;; - chime--make-tooltip
;; - chime--make-no-events-tooltip

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

;;; Setup and Teardown

(defun test-chime-make-tooltip-setup ()
  "Setup function run before each test."
  (chime-create-test-base-dir)
  (setq chime-modeline-tooltip-max-events 5)
  (setq chime-tooltip-header-format "Upcoming Events as of %a %b %d %Y @ %I:%M %p")
  (setq chime-display-time-format-string "%I:%M %p")
  (setq chime-time-left-format-at-event "right now")
  (setq chime-time-left-format-short "in %M")
  (setq chime-time-left-format-long "in %H %M"))

(defun test-chime-make-tooltip-teardown ()
  "Teardown function run after each test."
  (chime-delete-test-base-dir))

;;; Helper to build upcoming-events list items
;;; Each item is (EVENT TIME-INFO MINUTES-UNTIL) where
;;; TIME-INFO is (TIMESTAMP-STR . TIME-OBJECT)

(defun test-make-upcoming-item (title time minutes-until)
  "Create an upcoming-events list item for TITLE at TIME, MINUTES-UNTIL from now."
  (let ((ts (test-timestamp-string time)))
    (list `((title . ,title)
            (times . ((,ts . ,time)))
            (intervals . ((10 . medium))))
          (cons ts time)
          minutes-until)))

;;;; Tests for chime--make-tooltip

;;; Normal Cases

(ert-deftest test-chime-make-tooltip-single-event ()
  "Single event should produce tooltip with header, day label, and event line."
  (test-chime-make-tooltip-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (event-time (time-add now (seconds-to-time 1800))) ;; 30 min
             (upcoming (list (test-make-upcoming-item "Team Meeting" event-time 30))))
        (with-test-time now
          (let ((result (chime--make-tooltip upcoming)))
            (should (stringp result))
            ;; Should contain header
            (should (string-match-p "Upcoming Events" result))
            ;; Should contain the event title
            (should (string-match-p "Team Meeting" result))
            ;; Should contain day separator
            (should (string-match-p "─────────────" result)))))
    (test-chime-make-tooltip-teardown)))

(ert-deftest test-chime-make-tooltip-respects-max-events ()
  "Should respect chime-modeline-tooltip-max-events limit."
  (test-chime-make-tooltip-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (upcoming (list
                        (test-make-upcoming-item "Event 1" (time-add now (seconds-to-time 600)) 10)
                        (test-make-upcoming-item "Event 2" (time-add now (seconds-to-time 1200)) 20)
                        (test-make-upcoming-item "Event 3" (time-add now (seconds-to-time 1800)) 30)))
             (chime-modeline-tooltip-max-events 2))
        (with-test-time now
          (let ((result (chime--make-tooltip upcoming)))
            ;; Should show first 2 events
            (should (string-match-p "Event 1" result))
            (should (string-match-p "Event 2" result))
            ;; Should NOT show 3rd event
            (should-not (string-match-p "Event 3" result))
            ;; Should show "and 1 more"
            (should (string-match-p "1 more event" result)))))
    (test-chime-make-tooltip-teardown)))

(ert-deftest test-chime-make-tooltip-and-n-more-pluralized ()
  "The 'and N more' text should use correct pluralization."
  (test-chime-make-tooltip-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (upcoming (list
                        (test-make-upcoming-item "Event 1" (time-add now (seconds-to-time 600)) 10)
                        (test-make-upcoming-item "Event 2" (time-add now (seconds-to-time 1200)) 20)
                        (test-make-upcoming-item "Event 3" (time-add now (seconds-to-time 1800)) 30)
                        (test-make-upcoming-item "Event 4" (time-add now (seconds-to-time 2400)) 40)))
             (chime-modeline-tooltip-max-events 2))
        (with-test-time now
          (let ((result (chime--make-tooltip upcoming)))
            ;; 2 remaining - should be "events" (plural)
            (should (string-match-p "2 more events" result)))))
    (test-chime-make-tooltip-teardown)))

(ert-deftest test-chime-make-tooltip-nil-max-shows-all ()
  "When chime-modeline-tooltip-max-events is nil, all events should be shown."
  (test-chime-make-tooltip-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (upcoming (list
                        (test-make-upcoming-item "Event 1" (time-add now (seconds-to-time 600)) 10)
                        (test-make-upcoming-item "Event 2" (time-add now (seconds-to-time 1200)) 20)
                        (test-make-upcoming-item "Event 3" (time-add now (seconds-to-time 1800)) 30)))
             (chime-modeline-tooltip-max-events nil))
        (with-test-time now
          (let ((result (chime--make-tooltip upcoming)))
            (should (string-match-p "Event 1" result))
            (should (string-match-p "Event 2" result))
            (should (string-match-p "Event 3" result))
            ;; No "more" text
            (should-not (string-match-p "more event" result)))))
    (test-chime-make-tooltip-teardown)))

;;; Boundary Cases

(ert-deftest test-chime-make-tooltip-empty-list-returns-nil ()
  "Empty event list should return nil."
  (should (null (chime--make-tooltip '()))))

(ert-deftest test-chime-make-tooltip-nil-returns-nil ()
  "Nil input should return nil."
  (should (null (chime--make-tooltip nil))))

(ert-deftest test-chime-make-tooltip-max-events-equals-count ()
  "When max-events equals event count, no 'more' text should appear."
  (test-chime-make-tooltip-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (upcoming (list
                        (test-make-upcoming-item "Event 1" (time-add now (seconds-to-time 600)) 10)
                        (test-make-upcoming-item "Event 2" (time-add now (seconds-to-time 1200)) 20)))
             (chime-modeline-tooltip-max-events 2))
        (with-test-time now
          (let ((result (chime--make-tooltip upcoming)))
            (should (string-match-p "Event 1" result))
            (should (string-match-p "Event 2" result))
            (should-not (string-match-p "more event" result)))))
    (test-chime-make-tooltip-teardown)))

;;;; Tests for chime--make-no-events-tooltip

;;; Normal Cases

(ert-deftest test-chime-no-events-tooltip-shows-minutes ()
  "For less than 60 minutes, should show timeframe in minutes."
  (let ((result (chime--make-no-events-tooltip 30)))
    (should (stringp result))
    (should (string-match-p "30 minutes" result))
    (should (string-match-p "Left-click: Open calendar" result))))

(ert-deftest test-chime-no-events-tooltip-shows-hours ()
  "For 2+ hours, should show timeframe in hours."
  (let ((result (chime--make-no-events-tooltip 120)))
    (should (stringp result))
    (should (string-match-p "2 hours" result))))

(ert-deftest test-chime-no-events-tooltip-shows-days ()
  "For 7+ days, should show timeframe in days."
  (let ((result (chime--make-no-events-tooltip 10080))) ;; 7 days
    (should (stringp result))
    (should (string-match-p "7 days" result))))

(ert-deftest test-chime-no-events-tooltip-shows-fractional-days ()
  "For 1-7 days (24-167 hours), should show fractional days."
  (let ((result (chime--make-no-events-tooltip 2160))) ;; 36 hours = 1.5 days
    (should (stringp result))
    (should (string-match-p "1\\.5 days" result))))

(ert-deftest test-chime-no-events-tooltip-includes-header ()
  "Tooltip should include the header from chime-tooltip-header-format."
  (let ((result (chime--make-no-events-tooltip 60)))
    (should (string-match-p "Upcoming Events" result))))

(ert-deftest test-chime-no-events-tooltip-mentions-config-var ()
  "Tooltip should mention chime-tooltip-lookahead-hours for user guidance."
  (let ((result (chime--make-no-events-tooltip 60)))
    (should (string-match-p "chime-tooltip-lookahead-hours" result))))

;;; Boundary Cases

(ert-deftest test-chime-no-events-tooltip-exactly-60-minutes ()
  "Exactly 60 minutes (1 hour) should say '1 hour' not '1 hours'."
  (let ((result (chime--make-no-events-tooltip 60)))
    (should (stringp result))
    ;; A user expects correct English: "1 hour" not "1 hours"
    (should (string-match-p "1 hour[^s]" result))))

(ert-deftest test-chime-no-events-tooltip-exactly-1-day ()
  "Exactly 1440 minutes (24 hours / 1 day) should not say '1.0 days'."
  (let ((result (chime--make-no-events-tooltip 1440)))
    (should (stringp result))
    ;; User expects "1 day" or "1.0 day" — not "1.0 days"
    (should (string-match-p "1\\.0 day[^s]" result))))

(ert-deftest test-chime-no-events-tooltip-exactly-1-minute ()
  "1 minute should say '1 minute' not '1 minutes'."
  (let ((result (chime--make-no-events-tooltip 1)))
    (should (stringp result))
    ;; User expects "1 minute" not "1 minutes"
    (should (string-match-p "1 minute[^s]" result))))

(provide 'test-chime-make-tooltip)
;;; test-chime-make-tooltip.el ends here
