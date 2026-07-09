;;; test-chime-days-until-event.el --- Tests for chime--days-until-event -*- lexical-binding: t; -*-

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

;; Unit tests for `chime--days-until-event' and the notification text that
;; consumes it.
;;
;; The function maps over every timestamp on an event and keeps the day
;; count for the all-day ones.  Timed timestamps map to nil, so an event
;; mixing a timed and an all-day timestamp used to hand `-min' a list with
;; a nil in it and signal wrong-type-argument.  An event with no all-day
;; timestamp at all handed `-min' an empty list, which signals too.  Both
;; crash on every tick once `chime-day-wide-advance-notice' is on, walking
;; the async failure counter up to the persistent-failure warning.
;;
;; Tests cover normal cases, boundary cases, and error cases.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Helpers

;; `chime--days-until-event' measures against `current-time', so these
;; timestamps hang off the real now.  testutil-time's `test-time-now' is
;; deliberately 30 days ahead, which would make every expected day count
;; wrong here.

(defun test-chime-days--offset-time (days-from-now)
  "Return the time DAYS-FROM-NOW days from the real current time."
  (time-add (current-time) (days-to-time days-from-now)))

(defun test-chime-days--all-day (days-from-now)
  "Return an all-day timestamp cons cell DAYS-FROM-NOW days out."
  (let ((ts (test-timestamp-string (test-chime-days--offset-time days-from-now) t)))
    (cons ts (chime--timestamp-parse ts))))

(defun test-chime-days--timed (days-from-now hour minute)
  "Return a timed timestamp cons cell DAYS-FROM-NOW days out at HOUR:MINUTE."
  (let* ((decoded (decode-time (test-chime-days--offset-time days-from-now)))
         (time (encode-time 0 minute hour
                            (decoded-time-day decoded)
                            (decoded-time-month decoded)
                            (decoded-time-year decoded)))
         (ts (test-timestamp-string time)))
    (cons ts (chime--timestamp-parse ts))))

;;; Normal Cases

(ert-deftest test-chime-days-until-event-single-all-day-timestamp ()
  "A lone all-day timestamp yields its day count."
  (should (= (chime--days-until-event (list (test-chime-days--all-day 3))) 3)))

(ert-deftest test-chime-days-until-event-returns-the-soonest ()
  "The soonest all-day timestamp wins."
  (should (= (chime--days-until-event
              (list (test-chime-days--all-day 5)
                    (test-chime-days--all-day 2)
                    (test-chime-days--all-day 9)))
             2)))

;;; Boundary Cases

(ert-deftest test-chime-days-until-event-mixed-timed-and-all-day ()
  "An event mixing a timed and an all-day timestamp ignores the timed one.
The timed timestamp maps to nil, which must not reach `-min'."
  (should (= (chime--days-until-event
              (list (test-chime-days--timed 8 14 0)
                    (test-chime-days--all-day 4)))
             4)))

(ert-deftest test-chime-days-until-event-timed-only-returns-nil ()
  "With no all-day timestamp there is no day count, so the result is nil."
  (should-not (chime--days-until-event
               (list (test-chime-days--timed 2 9 30)
                     (test-chime-days--timed 6 17 0)))))

(ert-deftest test-chime-days-until-event-empty-list-returns-nil ()
  "An event with no timestamps at all yields nil rather than signalling."
  (should-not (chime--days-until-event '())))

;;; Error Cases

(ert-deftest test-chime-days-until-event-mixed-timestamps-do-not-signal ()
  "The mixed-timestamp case must not signal wrong-type-argument.
This is the crash that recurred every tick and drove the async failure
counter to the persistent-failure warning."
  (should-not (condition-case nil
                  (progn (chime--days-until-event
                          (list (test-chime-days--timed 8 14 0)
                                (test-chime-days--all-day 4)))
                         nil)
                (error t))))

(ert-deftest test-chime-day-wide-notification-text-survives-nil-day-count ()
  "The notification text falls back rather than crashing on a nil day count.
`chime--days-until-event' returns nil when an event has no all-day
timestamp, so the advance-notice branch must not compare nil to a number."
  (let ((chime-day-wide-advance-notice 7)
        (event `((title . "Timed Only")
                 (times . (,(test-chime-days--timed 3 10 0)))
                 (intervals . ((0)))
                 (marker-file . "/tmp/test.org")
                 (marker-pos . 1))))
    (cl-letf (((symbol-function 'chime--event-has-any-passed-time)
               (lambda (_event) nil))
              ((symbol-function 'chime--event-within-advance-notice-window)
               (lambda (_event) t)))
      (let ((text (chime--day-wide-notification-text event)))
        (should (stringp text))
        (should (string-match-p "Timed Only" text))))))

(provide 'test-chime-days-until-event)
;;; test-chime-days-until-event.el ends here
