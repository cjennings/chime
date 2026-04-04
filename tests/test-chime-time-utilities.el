;;; test-chime-time-utilities.el --- Tests for time utility functions -*- lexical-binding: t; -*-

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

;; Unit tests for chime time utility functions:
;; - chime-get-minutes-into-day
;; - chime-get-hours-minutes-from-time
;; - chime-set-hours-minutes-for-time

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

;;;; Tests for chime-get-minutes-into-day

;;; Normal Cases

(ert-deftest test-chime-get-minutes-into-day-noon ()
  "Noon (12:00) should be 720 minutes into the day."
  (should (= 720 (chime-get-minutes-into-day "12:00"))))

(ert-deftest test-chime-get-minutes-into-day-afternoon ()
  "14:30 should be 870 minutes into the day."
  (should (= 870 (chime-get-minutes-into-day "14:30"))))

(ert-deftest test-chime-get-minutes-into-day-morning ()
  "8:00 should be 480 minutes into the day."
  (should (= 480 (chime-get-minutes-into-day "8:00"))))

;;; Boundary Cases

(ert-deftest test-chime-get-minutes-into-day-midnight ()
  "Midnight (0:00) should be 0 minutes into the day."
  (should (= 0 (chime-get-minutes-into-day "0:00"))))

(ert-deftest test-chime-get-minutes-into-day-end-of-day ()
  "23:59 should be 1439 minutes into the day."
  (should (= 1439 (chime-get-minutes-into-day "23:59"))))

(ert-deftest test-chime-get-minutes-into-day-one-minute-past-midnight ()
  "0:01 should be 1 minute into the day."
  (should (= 1 (chime-get-minutes-into-day "0:01"))))

;;;; Tests for chime-get-hours-minutes-from-time

;;; Normal Cases

(ert-deftest test-chime-get-hours-minutes-afternoon ()
  "14:30 should return (14 30)."
  (should (equal '(14 30) (chime-get-hours-minutes-from-time "14:30"))))

(ert-deftest test-chime-get-hours-minutes-morning ()
  "8:00 should return (8 0)."
  (should (equal '(8 0) (chime-get-hours-minutes-from-time "8:00"))))

(ert-deftest test-chime-get-hours-minutes-with-minutes ()
  "9:45 should return (9 45)."
  (should (equal '(9 45) (chime-get-hours-minutes-from-time "9:45"))))

;;; Boundary Cases

(ert-deftest test-chime-get-hours-minutes-midnight ()
  "0:00 should return (0 0)."
  (should (equal '(0 0) (chime-get-hours-minutes-from-time "0:00"))))

(ert-deftest test-chime-get-hours-minutes-exact-hour ()
  "10:00 should return (10 0) with no leftover minutes."
  (should (equal '(10 0) (chime-get-hours-minutes-from-time "10:00"))))

(ert-deftest test-chime-get-hours-minutes-end-of-day ()
  "23:59 should return (23 59)."
  (should (equal '(23 59) (chime-get-hours-minutes-from-time "23:59"))))

(ert-deftest test-chime-get-hours-minutes-noon ()
  "12:00 should return (12 0)."
  (should (equal '(12 0) (chime-get-hours-minutes-from-time "12:00"))))

;;;; Tests for chime-set-hours-minutes-for-time

;;; Normal Cases

(ert-deftest test-chime-set-hours-minutes-preserves-date ()
  "Setting hours/minutes should preserve the date."
  (let* ((base (test-time-tomorrow-at 10 0))
         (result (chime-set-hours-minutes-for-time base 14 30))
         (decoded (decode-time result))
         (base-decoded (decode-time base)))
    ;; Date should be the same
    (should (= (decoded-time-day base-decoded) (decoded-time-day decoded)))
    (should (= (decoded-time-month base-decoded) (decoded-time-month decoded)))
    (should (= (decoded-time-year base-decoded) (decoded-time-year decoded)))
    ;; Time should be changed
    (should (= 14 (decoded-time-hour decoded)))
    (should (= 30 (decoded-time-minute decoded)))
    (should (= 0 (decoded-time-second decoded)))))

(ert-deftest test-chime-set-hours-minutes-changes-time ()
  "Setting different hours/minutes should produce different time."
  (let* ((base (test-time-tomorrow-at 10 0))
         (result (chime-set-hours-minutes-for-time base 15 45))
         (decoded (decode-time result)))
    (should (= 15 (decoded-time-hour decoded)))
    (should (= 45 (decoded-time-minute decoded)))))

;;; Boundary Cases

(ert-deftest test-chime-set-hours-minutes-midnight ()
  "Setting to midnight (0, 0) should work."
  (let* ((base (test-time-tomorrow-at 10 0))
         (result (chime-set-hours-minutes-for-time base 0 0))
         (decoded (decode-time result)))
    (should (= 0 (decoded-time-hour decoded)))
    (should (= 0 (decoded-time-minute decoded)))))

(ert-deftest test-chime-set-hours-minutes-end-of-day ()
  "Setting to 23:59 should work."
  (let* ((base (test-time-tomorrow-at 10 0))
         (result (chime-set-hours-minutes-for-time base 23 59))
         (decoded (decode-time result)))
    (should (= 23 (decoded-time-hour decoded)))
    (should (= 59 (decoded-time-minute decoded)))))

(ert-deftest test-chime-set-hours-minutes-roundtrip ()
  "Extracting hours/minutes and setting them back should produce same time-of-day."
  (let* ((base (test-time-tomorrow-at 14 30))
         (hm (chime-get-hours-minutes-from-time "14:30"))
         (result (chime-set-hours-minutes-for-time base (car hm) (cadr hm)))
         (decoded (decode-time result)))
    (should (= 14 (decoded-time-hour decoded)))
    (should (= 30 (decoded-time-minute decoded)))))

(ert-deftest test-chime-set-hours-minutes-seconds-always-zero ()
  "Seconds should always be set to 0 regardless of base time."
  (let* ((base (test-time-now)) ;; may have non-zero seconds internally
         (result (chime-set-hours-minutes-for-time base 10 0))
         (decoded (decode-time result)))
    (should (= 0 (decoded-time-second decoded)))))

(provide 'test-chime-time-utilities)
;;; test-chime-time-utilities.el ends here
