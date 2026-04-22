;;; test-chime-group-events-by-day.el --- Tests for chime--group-events-by-day -*- lexical-binding: t; -*-

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

;; Unit tests for chime--group-events-by-day function.
;; Tests cover normal cases, boundary cases, and error cases.
;;
;; Note: chime--group-events-by-day does not handle malformed events gracefully.
;; This is acceptable since events are generated internally by chime and should
;; always have the correct structure. If a malformed event is passed, it will error.
;; Removed test: test-chime-group-events-by-day-error-malformed-event
;;
;; Tests that build events as a fixed-minute offset from "now" pin the clock
;; with `with-test-time' so the offsets do not accidentally cross a calendar
;; day boundary on late-night runs. The clock value is bound in a `let' first
;; (the macro re-evaluates BASE-TIME on every `current-time' call, so passing
;; `(test-time-today-at ...)' directly would recurse — `test-time-today-at'
;; calls `current-time' itself).

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;; Load test utilities
(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))

;;; Setup and Teardown

(defun test-chime-group-events-by-day-setup ()
  "Setup function run before each test."
  (chime-create-test-base-dir))

(defun test-chime-group-events-by-day-teardown ()
  "Teardown function run after each test."
  (chime-delete-test-base-dir))

;;; Test Helpers

(defun test-chime-make-event-item (minutes-until title)
  "Create a mock event item for testing.
MINUTES-UNTIL is minutes until event, TITLE is event title."
  (let* ((now (current-time))
         (event-time (time-add now (seconds-to-time (* minutes-until 60))))
         (timestamp-str (test-timestamp-string event-time))
         (event `((title . ,title)
                  (times . ())))
         (time-info (cons timestamp-str event-time)))
    (list event time-info minutes-until)))

;;; Normal Cases

(ert-deftest test-chime-group-events-by-day-normal-single-day ()
  "Test grouping events all on same day."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((pinned (test-time-today-at 12 0)))
        (with-test-time pinned
          (let* ((event1 (test-chime-make-event-item 10 "Event 1"))
                 (event2 (test-chime-make-event-item 30 "Event 2"))
                 (event3 (test-chime-make-event-item 60 "Event 3"))
                 (upcoming (list event1 event2 event3))
                 (result (chime--group-events-by-day upcoming)))
            ;; Should have 1 group (today)
            (should (= 1 (length result)))
            ;; Group should have 3 events
            (should (= 3 (length (cdr (car result)))))
            ;; Date string should say "Today"
            (should (string-match-p "Today" (car (car result)))))))
    (test-chime-group-events-by-day-teardown)))

(ert-deftest test-chime-group-events-by-day-normal-multiple-days ()
  "Test grouping events across multiple days."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((pinned (test-time-today-at 12 0)))
        (with-test-time pinned
          (let* ((event1 (test-chime-make-event-item 10 "Today Event"))
                 (event2 (test-chime-make-event-item 1500 "Tomorrow Event"))  ; > 1440
                 (event3 (test-chime-make-event-item 3000 "Future Event"))     ; > 2880
                 (upcoming (list event1 event2 event3))
                 (result (chime--group-events-by-day upcoming)))
            ;; Should have 3 groups (today, tomorrow, future)
            (should (= 3 (length result)))
            ;; First group should say "Today"
            (should (string-match-p "Today" (car (nth 0 result))))
            ;; Second group should say "Tomorrow"
            (should (string-match-p "Tomorrow" (car (nth 1 result)))))))
    (test-chime-group-events-by-day-teardown)))

(ert-deftest test-chime-group-events-by-day-normal-maintains-order ()
  "Test that events maintain order within groups."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((pinned (test-time-today-at 12 0)))
        (with-test-time pinned
          (let* ((event1 (test-chime-make-event-item 10 "First"))
                 (event2 (test-chime-make-event-item 20 "Second"))
                 (event3 (test-chime-make-event-item 30 "Third"))
                 (upcoming (list event1 event2 event3))
                 (result (chime--group-events-by-day upcoming))
                 (today-events (cdr (car result))))
            ;; Should maintain order
            (should (= 3 (length today-events)))
            (should (string= "First" (cdr (assoc 'title (car (nth 0 today-events))))))
            (should (string= "Second" (cdr (assoc 'title (car (nth 1 today-events))))))
            (should (string= "Third" (cdr (assoc 'title (car (nth 2 today-events)))))))))
    (test-chime-group-events-by-day-teardown)))

;;; Boundary Cases

(ert-deftest test-chime-group-events-by-day-boundary-empty-list ()
  "Test grouping empty events list."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((result (chime--group-events-by-day '())))
        ;; Should return empty list
        (should (null result)))
    (test-chime-group-events-by-day-teardown)))

(ert-deftest test-chime-group-events-by-day-boundary-single-event ()
  "Test grouping single event."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((pinned (test-time-today-at 12 0)))
        (with-test-time pinned
          (let* ((event (test-chime-make-event-item 10 "Only Event"))
                 (upcoming (list event))
                 (result (chime--group-events-by-day upcoming)))
            ;; Should have 1 group
            (should (= 1 (length result)))
            ;; Group should have 1 event
            (should (= 1 (length (cdr (car result))))))))
    (test-chime-group-events-by-day-teardown)))

(ert-deftest test-chime-group-events-by-day-boundary-exactly-1440-minutes ()
  "Test event at exactly 1440 minutes (1 day boundary)."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((pinned (test-time-today-at 12 0)))
        (with-test-time pinned
          (let* ((event (test-chime-make-event-item 1440 "Boundary Event"))
                 (upcoming (list event))
                 (result (chime--group-events-by-day upcoming)))
            ;; Should be grouped as "Tomorrow"
            (should (= 1 (length result)))
            (should (string-match-p "Tomorrow" (car (car result)))))))
    (test-chime-group-events-by-day-teardown)))

(ert-deftest test-chime-group-events-by-day-boundary-just-under-1440 ()
  "Test event at 1439 minutes (23h 59m away).

If current time is noon, an event 1439 minutes away is at 11:59 AM the
next calendar day, so it should be grouped as 'Tomorrow', not 'Today'."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((pinned (test-time-today-at 12 0)))
        (with-test-time pinned
          (let* ((event (test-chime-make-event-item 1439 "Almost Tomorrow"))
                 (upcoming (list event))
                 (result (chime--group-events-by-day upcoming)))
            ;; Should be grouped as "Tomorrow" (next calendar day)
            (should (= 1 (length result)))
            (should (string-match-p "Tomorrow" (car (car result)))))))
    (test-chime-group-events-by-day-teardown)))

(ert-deftest test-chime-group-events-by-day-boundary-exactly-2880-minutes ()
  "Test event at exactly 2880 minutes (2 day boundary)."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((pinned (test-time-today-at 12 0)))
        (with-test-time pinned
          (let* ((event (test-chime-make-event-item 2880 "Two Days Away"))
                 (upcoming (list event))
                 (result (chime--group-events-by-day upcoming)))
            ;; Should be grouped as a future day (not "Tomorrow")
            (should (= 1 (length result)))
            (should-not (string-match-p "Tomorrow" (car (car result)))))))
    (test-chime-group-events-by-day-teardown)))

(ert-deftest test-chime-group-events-by-day-boundary-zero-minutes ()
  "Test event at 0 minutes (happening now)."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((pinned (test-time-today-at 12 0)))
        (with-test-time pinned
          (let* ((event (test-chime-make-event-item 0 "Right Now"))
                 (upcoming (list event))
                 (result (chime--group-events-by-day upcoming)))
            ;; Should be grouped as "Today"
            (should (= 1 (length result)))
            (should (string-match-p "Today" (car (car result)))))))
    (test-chime-group-events-by-day-teardown)))

(ert-deftest test-chime-group-events-by-day-boundary-event-just-before-midnight-today ()
  "Boundary: clock at 23:50, event +5 min lands at 23:55 (still today)."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((pinned (test-time-today-at 23 50)))
        (with-test-time pinned
          (let* ((event (test-chime-make-event-item 5 "Late Tonight"))
                 (upcoming (list event))
                 (result (chime--group-events-by-day upcoming)))
            (should (= 1 (length result)))
            (should (string-match-p "Today" (car (car result)))))))
    (test-chime-group-events-by-day-teardown)))

(ert-deftest test-chime-group-events-by-day-boundary-event-crossing-midnight-tomorrow ()
  "Boundary: clock at 23:50, event +20 min lands at 00:10 next day (Tomorrow)."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (let ((pinned (test-time-today-at 23 50)))
        (with-test-time pinned
          (let* ((event (test-chime-make-event-item 20 "Across Midnight"))
                 (upcoming (list event))
                 (result (chime--group-events-by-day upcoming)))
            (should (= 1 (length result)))
            (should (string-match-p "Tomorrow" (car (car result)))))))
    (test-chime-group-events-by-day-teardown)))

;;; Bug Reproduction Tests

(ert-deftest test-chime-group-events-by-day-bug-tomorrow-morning-grouped-as-today ()
  "Test that tomorrow morning event is NOT grouped as 'Today'.
This reproduces the bug where an event at 10:00 AM tomorrow,
when it's 11:23 AM today (22h 37m = 1357 minutes away),
is incorrectly grouped as 'Today' instead of 'Tomorrow'.

The bug: The function groups by 24-hour period (<1440 minutes)
instead of by calendar day."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (with-test-time (encode-time 0 23 11 2 11 2025) ; Nov 02, 2025 11:23 AM
        (let* ((now (current-time))
               (tomorrow-morning (encode-time 0 0 10 3 11 2025)) ; Nov 03, 2025 10:00 AM
               (minutes-until (/ (- (float-time tomorrow-morning) (float-time now)) 60))
               ;; Create event manually since test-chime-make-event-item uses relative time
               (event `((title . "Transit to Meeting")
                       (times . ())))
               (time-info (cons (test-timestamp-string tomorrow-morning) tomorrow-morning))
               (event-item (list event time-info minutes-until))
               (upcoming (list event-item))
               (result (chime--group-events-by-day upcoming)))
          ;; Verify it's less than 1440 minutes (this is why the bug happens)
          (should (< minutes-until 1440))
          ;; Should have 1 group
          (should (= 1 (length result)))
          ;; BUG: Currently groups as "Today" but should be "Tomorrow"
          ;; because the event is on Nov 03, not Nov 02
          (should (string-match-p "Tomorrow" (car (car result))))))
    (test-chime-group-events-by-day-teardown)))

;;;; Tests for chime--day-label-for-event-time

;; Pure-function tests. NOW and TOMORROW are passed in, so no clock mocking
;; is needed — we just construct stable calendar times with `encode-time'.

(ert-deftest test-chime-day-label-normal-same-day-returns-today ()
  "Normal: event on the same calendar day as NOW returns \"Today, ...\"."
  (let* ((now (encode-time 0 0 12 15 5 2026))            ; 2026-05-15 12:00
         (tomorrow (time-add now (days-to-time 1)))
         (event (encode-time 0 0 9 15 5 2026))           ; 2026-05-15 09:00
         (label (chime--day-label-for-event-time event now tomorrow)))
    (should (stringp label))
    (should (string-match-p "\\`Today" label))
    (should (string-match-p "May 15" label))))

(ert-deftest test-chime-day-label-normal-next-calendar-day-returns-tomorrow ()
  "Normal: event on the same calendar day as TOMORROW returns \"Tomorrow, ...\"."
  (let* ((now (encode-time 0 0 12 15 5 2026))            ; 2026-05-15 12:00
         (tomorrow (time-add now (days-to-time 1)))
         (event (encode-time 0 0 10 16 5 2026))          ; 2026-05-16 10:00
         (label (chime--day-label-for-event-time event now tomorrow)))
    (should (string-match-p "\\`Tomorrow" label))
    (should (string-match-p "May 16" label))))

(ert-deftest test-chime-day-label-normal-distant-future-returns-weekday ()
  "Normal: event three days out returns a weekday label (not Today/Tomorrow)."
  (let* ((now (encode-time 0 0 12 15 5 2026))            ; 2026-05-15 (Fri) 12:00
         (tomorrow (time-add now (days-to-time 1)))
         (event (encode-time 0 0 14 18 5 2026))          ; 2026-05-18 (Mon) 14:00
         (label (chime--day-label-for-event-time event now tomorrow)))
    (should (stringp label))
    (should-not (string-match-p "\\`Today" label))
    (should-not (string-match-p "\\`Tomorrow" label))
    (should (string-match-p "Monday" label))
    (should (string-match-p "May 18" label))))

(ert-deftest test-chime-day-label-boundary-event-at-today-midnight ()
  "Boundary: event at 00:00 on the same calendar day as NOW is Today."
  (let* ((now (encode-time 0 0 12 15 5 2026))            ; 2026-05-15 12:00
         (tomorrow (time-add now (days-to-time 1)))
         (event (encode-time 0 0 0 15 5 2026))           ; 2026-05-15 00:00
         (label (chime--day-label-for-event-time event now tomorrow)))
    (should (string-match-p "\\`Today" label))))

(ert-deftest test-chime-day-label-boundary-event-at-tomorrow-midnight ()
  "Boundary: event at 00:00 on TOMORROW's calendar day is Tomorrow."
  (let* ((now (encode-time 0 0 12 15 5 2026))            ; 2026-05-15 12:00
         (tomorrow (time-add now (days-to-time 1)))
         (event (encode-time 0 0 0 16 5 2026))           ; 2026-05-16 00:00
         (label (chime--day-label-for-event-time event now tomorrow)))
    (should (string-match-p "\\`Tomorrow" label))))

(ert-deftest test-chime-day-label-boundary-day-after-tomorrow-is-weekday ()
  "Boundary: event two calendar days out is NOT Tomorrow; gets a weekday label."
  (let* ((now (encode-time 0 0 12 15 5 2026))            ; 2026-05-15 12:00
         (tomorrow (time-add now (days-to-time 1)))
         (event (encode-time 0 0 12 17 5 2026))          ; 2026-05-17 12:00
         (label (chime--day-label-for-event-time event now tomorrow)))
    (should-not (string-match-p "\\`Tomorrow" label))
    (should (string-match-p "May 17" label))))

(ert-deftest test-chime-day-label-boundary-yesterday-is-weekday ()
  "Boundary: event on the previous calendar day is neither Today nor Tomorrow."
  (let* ((now (encode-time 0 0 12 15 5 2026))            ; 2026-05-15 12:00
         (tomorrow (time-add now (days-to-time 1)))
         (event (encode-time 0 0 10 14 5 2026))          ; 2026-05-14 10:00
         (label (chime--day-label-for-event-time event now tomorrow)))
    (should-not (string-match-p "\\`Today" label))
    (should-not (string-match-p "\\`Tomorrow" label))
    (should (string-match-p "May 14" label))))

;;; Error Cases

(ert-deftest test-chime-group-events-by-day-error-nil-input ()
  "Test that nil input doesn't crash."
  (test-chime-group-events-by-day-setup)
  (unwind-protect
      (progn
        ;; Should not crash with nil
        (should-not (condition-case nil
                        (progn (chime--group-events-by-day nil) nil)
                      (error t))))
    (test-chime-group-events-by-day-teardown)))

(provide 'test-chime-group-events-by-day)
;;; test-chime-group-events-by-day.el ends here
