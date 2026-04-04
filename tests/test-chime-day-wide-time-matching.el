;;; test-chime-day-wide-time-matching.el --- Tests for day-wide time matching -*- lexical-binding: t; -*-

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

;; Unit tests for day-wide time matching functions:
;; - chime-current-time-matches-time-of-day-string
;; - chime-current-time-is-day-wide-time
;;
;; These functions determine when to fire notifications for all-day events
;; by comparing the current time to configured alert times like "08:00".
;;
;; IMPORTANT: Mock times must be computed BEFORE entering with-test-time,
;; because test-time-today-at calls current-time internally.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;; Load test utilities
(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))

;;;; Tests for chime-current-time-matches-time-of-day-string

;;; Normal Cases

(ert-deftest test-chime-time-matches-string-exact-match ()
  "Should return truthy when current time matches the time-of-day string."
  (let ((mock-time (test-time-today-at 8 0)))
    (with-test-time mock-time
      (should (chime-current-time-matches-time-of-day-string "8:00")))))

(ert-deftest test-chime-time-matches-string-no-match ()
  "Should return nil when current time does not match."
  (let ((mock-time (test-time-today-at 9 0)))
    (with-test-time mock-time
      (should-not (chime-current-time-matches-time-of-day-string "8:00")))))

(ert-deftest test-chime-time-matches-string-afternoon ()
  "Should match afternoon times correctly."
  (let ((mock-time (test-time-today-at 17 0)))
    (with-test-time mock-time
      (should (chime-current-time-matches-time-of-day-string "17:00")))))

;;; Boundary Cases

(ert-deftest test-chime-time-matches-string-midnight ()
  "Should match midnight (00:00)."
  (let ((mock-time (test-time-today-at 0 0)))
    (with-test-time mock-time
      (should (chime-current-time-matches-time-of-day-string "0:00")))))

(ert-deftest test-chime-time-matches-string-end-of-day ()
  "Should match 23:59."
  (let ((mock-time (test-time-today-at 23 59)))
    (with-test-time mock-time
      (should (chime-current-time-matches-time-of-day-string "23:59")))))

(ert-deftest test-chime-time-matches-string-off-by-one-minute ()
  "One minute off should not match."
  (let ((mock-time (test-time-today-at 8 1)))
    (with-test-time mock-time
      (should-not (chime-current-time-matches-time-of-day-string "8:00")))))

(ert-deftest test-chime-time-matches-string-leading-zero ()
  "Should match with leading zero in time string (08:00)."
  (let ((mock-time (test-time-today-at 8 0)))
    (with-test-time mock-time
      (should (chime-current-time-matches-time-of-day-string "08:00")))))

;;;; Tests for chime-current-time-is-day-wide-time

;;; Normal Cases

(ert-deftest test-chime-is-day-wide-time-matches-single-entry ()
  "Should return truthy when current time matches the configured alert time."
  (let ((mock-time (test-time-today-at 8 0)))
    (with-test-time mock-time
      (let ((chime-day-wide-alert-times '("08:00")))
        (should (chime-current-time-is-day-wide-time))))))

(ert-deftest test-chime-is-day-wide-time-matches-second-entry ()
  "Should return truthy when current time matches any entry, not just first."
  (let ((mock-time (test-time-today-at 17 0)))
    (with-test-time mock-time
      (let ((chime-day-wide-alert-times '("08:00" "17:00")))
        (should (chime-current-time-is-day-wide-time))))))

(ert-deftest test-chime-is-day-wide-time-no-match ()
  "Should return nil when current time matches no configured alert times."
  (let ((mock-time (test-time-today-at 12 0)))
    (with-test-time mock-time
      (let ((chime-day-wide-alert-times '("08:00" "17:00")))
        (should-not (chime-current-time-is-day-wide-time))))))

;;; Boundary Cases

(ert-deftest test-chime-is-day-wide-time-empty-list ()
  "Should return nil when alert times list is empty."
  (let ((mock-time (test-time-today-at 8 0)))
    (with-test-time mock-time
      (let ((chime-day-wide-alert-times '()))
        (should-not (chime-current-time-is-day-wide-time))))))

(ert-deftest test-chime-is-day-wide-time-nil-list ()
  "Should return nil when alert times list is nil."
  (let ((mock-time (test-time-today-at 8 0)))
    (with-test-time mock-time
      (let ((chime-day-wide-alert-times nil))
        (should-not (chime-current-time-is-day-wide-time))))))

(ert-deftest test-chime-is-day-wide-time-matches-first-of-many ()
  "Should return truthy when matching the first of several alert times."
  (let ((mock-time (test-time-today-at 8 0)))
    (with-test-time mock-time
      (let ((chime-day-wide-alert-times '("08:00" "12:00" "17:00")))
        (should (chime-current-time-is-day-wide-time))))))

(provide 'test-chime-day-wide-time-matching)
;;; test-chime-day-wide-time-matching.el ends here
