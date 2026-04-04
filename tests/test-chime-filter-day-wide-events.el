;;; test-chime-filter-day-wide-events.el --- Tests for chime--filter-day-wide-events -*- lexical-binding: t; -*-

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

;; Unit tests for chime--filter-day-wide-events function.
;; This function filters a times alist to keep only entries that have
;; a time component in their timestamp string (i.e., timed events),
;; removing all-day events.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;; Load test utilities
(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))

;;; Normal Cases

(ert-deftest test-chime-filter-day-wide-events-keeps-timed-event ()
  "Timed events (with HH:MM) should be kept."
  (let* ((time (test-time-tomorrow-at 14 30))
         (ts (test-timestamp-string time))
         (times (list (cons ts time)))
         (result (chime--filter-day-wide-events times)))
    (should (= 1 (length result)))
    (should (equal (car (car result)) ts))))

(ert-deftest test-chime-filter-day-wide-events-removes-all-day-event ()
  "All-day events (no HH:MM) should be removed."
  (let* ((time (test-time-tomorrow-at 0 0))
         (ts (test-timestamp-string time t)) ;; all-day = t
         (times (list (cons ts time)))
         (result (chime--filter-day-wide-events times)))
    (should (= 0 (length result)))))

(ert-deftest test-chime-filter-day-wide-events-mixed-keeps-only-timed ()
  "Mixed list should keep only timed events, removing all-day ones."
  (let* ((timed-time (test-time-tomorrow-at 14 30))
         (allday-time (test-time-days-from-now 2))
         (timed-ts (test-timestamp-string timed-time))
         (allday-ts (test-timestamp-string allday-time t))
         (times (list (cons timed-ts timed-time)
                      (cons allday-ts allday-time)))
         (result (chime--filter-day-wide-events times)))
    (should (= 1 (length result)))
    (should (equal (car (car result)) timed-ts))))

(ert-deftest test-chime-filter-day-wide-events-multiple-timed-all-kept ()
  "Multiple timed events should all be kept."
  (let* ((time1 (test-time-tomorrow-at 9 0))
         (time2 (test-time-tomorrow-at 14 30))
         (time3 (test-time-tomorrow-at 17 0))
         (times (list (cons (test-timestamp-string time1) time1)
                      (cons (test-timestamp-string time2) time2)
                      (cons (test-timestamp-string time3) time3)))
         (result (chime--filter-day-wide-events times)))
    (should (= 3 (length result)))))

;;; Boundary Cases

(ert-deftest test-chime-filter-day-wide-events-empty-list ()
  "Empty times list should return empty list."
  (should (null (chime--filter-day-wide-events '()))))

(ert-deftest test-chime-filter-day-wide-events-single-timed ()
  "Single timed event should return list of one."
  (let* ((time (test-time-tomorrow-at 10 0))
         (ts (test-timestamp-string time))
         (result (chime--filter-day-wide-events (list (cons ts time)))))
    (should (= 1 (length result)))))

(ert-deftest test-chime-filter-day-wide-events-single-all-day ()
  "Single all-day event should return empty list."
  (let* ((time (test-time-tomorrow-at 0 0))
         (ts (test-timestamp-string time t))
         (result (chime--filter-day-wide-events (list (cons ts time)))))
    (should (null result))))

(ert-deftest test-chime-filter-day-wide-events-repeating-timed-kept ()
  "Repeating timestamp with time component should be kept."
  (let* ((time (test-time-tomorrow-at 9 0))
         (ts (test-timestamp-repeating time "+1w"))
         (result (chime--filter-day-wide-events (list (cons ts time)))))
    (should (= 1 (length result)))))

(ert-deftest test-chime-filter-day-wide-events-repeating-all-day-removed ()
  "Repeating timestamp without time component should be removed."
  (let* ((time (test-time-tomorrow-at 0 0))
         (ts (test-timestamp-repeating time "+1y" t)) ;; all-day repeating
         (result (chime--filter-day-wide-events (list (cons ts time)))))
    (should (null result))))

;;; Error Cases

(ert-deftest test-chime-filter-day-wide-events-all-entries-all-day ()
  "When all entries are all-day, should return empty list."
  (let* ((time1 (test-time-tomorrow-at 0 0))
         (time2 (test-time-days-from-now 2))
         (times (list (cons (test-timestamp-string time1 t) time1)
                      (cons (test-timestamp-string time2 t) time2)))
         (result (chime--filter-day-wide-events times)))
    (should (null result))))

(provide 'test-chime-filter-day-wide-events)
;;; test-chime-filter-day-wide-events.el ends here
