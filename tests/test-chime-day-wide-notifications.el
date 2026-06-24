;;; test-chime-day-wide-notifications.el --- Tests for chime--day-wide-notifications -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;; Author: Craig Jennings <c@cjennings.net>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Direct unit tests for `chime--day-wide-notifications', which combines the
;; day-wide filter, the notification-text builder, dedup, and severity
;; wrapping into a single pipeline.
;;
;; Mock-clock note: `with-test-time' replaces `current-time' with a lambda
;; that returns the captured base time.  The base must be computed BEFORE
;; entering the macro, because `test-time-now' itself calls `current-time'
;; — passing `(test-time-now)' inside the macro causes infinite recursion.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

(ert-deftest test-chime-day-wide-notifications-normal-wraps-with-medium-severity ()
  "Normal: each generated text is wrapped as (TEXT . \\='medium)."
  (let* ((base (test-time-now))
         (today (test-time-today-at 0 0))
         (ts (test-timestamp-string today t))
         (event (chime--make-event (list (cons ts nil))
                                   "Birthday"
                                   '((0 . medium))))
         (chime-day-wide-advance-notice nil)
         (chime-show-any-overdue-with-day-wide-alerts t))
    (with-test-time base
      (let ((result (chime--day-wide-notifications (list event))))
        (should (= 1 (length result)))
        (should (eq 'medium (cdr (car result))))
        (should (stringp (car (car result))))
        (should (string-match-p "Birthday" (car (car result))))))))

(ert-deftest test-chime-day-wide-notifications-boundary-empty-events ()
  "Boundary: empty events list yields empty notification list."
  (should (null (chime--day-wide-notifications '()))))

(ert-deftest test-chime-day-wide-notifications-boundary-deduplicates-identical-text ()
  "Boundary: two events producing identical notification text collapse to one."
  (let* ((base (test-time-now))
         (today (test-time-today-at 0 0))
         (ts (test-timestamp-string today t))
         (event1 (chime--make-event (list (cons ts nil))
                                    "Birthday"
                                    '((0 . medium))))
         (event2 (chime--make-event (list (cons ts nil))
                                    "Birthday"
                                    '((0 . medium))))
         (chime-day-wide-advance-notice nil)
         (chime-show-any-overdue-with-day-wide-alerts t))
    (with-test-time base
      (let ((result (chime--day-wide-notifications (list event1 event2))))
        (should (= 1 (length result)))))))

(ert-deftest test-chime-day-wide-notifications-boundary-filters-non-day-wide-events ()
  "Boundary: events that don't pass the day-wide filter contribute nothing."
  (let* ((base (test-time-now))
         (future (test-time-tomorrow-at 9 0))
         (ts (test-timestamp-string future))
         (event (chime--make-event (list (cons ts future))
                                   "Future Timed"
                                   '((10 . medium))))
         (chime-day-wide-advance-notice nil)
         (chime-show-any-overdue-with-day-wide-alerts t))
    (with-test-time base
      (should (null (chime--day-wide-notifications (list event)))))))

(provide 'test-chime-day-wide-notifications)
;;; test-chime-day-wide-notifications.el ends here
