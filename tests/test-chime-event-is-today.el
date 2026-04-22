;;; test-chime--event-is-today.el --- Tests for chime--event-is-today -*- lexical-binding: t; -*-

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

;; Unit tests for chime--event-is-today function.
;; This function checks if an event has any timestamps specifically on today's
;; date (not past days, not future days).
;;
;; NOTE: These tests use real dates (not with-test-time) because
;; chime--event-is-today uses (decode-time) without arguments internally,
;; which calls the C-level current_time and bypasses Lisp-level mocking.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;; Load test utilities
(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))

;;; Helpers — build events at real dates

(defun test--real-today-at (hour minute)
  "Return Emacs time for the real today at HOUR:MINUTE."
  (let ((d (decode-time (current-time))))
    (encode-time 0 minute hour
                 (decoded-time-day d)
                 (decoded-time-month d)
                 (decoded-time-year d))))

(defun test--real-yesterday-at (hour minute)
  "Return Emacs time for the real yesterday at HOUR:MINUTE."
  (let ((d (decode-time (time-subtract (current-time) (days-to-time 1)))))
    (encode-time 0 minute hour
                 (decoded-time-day d)
                 (decoded-time-month d)
                 (decoded-time-year d))))

(defun test--real-tomorrow-at (hour minute)
  "Return Emacs time for the real tomorrow at HOUR:MINUTE."
  (let ((d (decode-time (time-add (current-time) (days-to-time 1)))))
    (encode-time 0 minute hour
                 (decoded-time-day d)
                 (decoded-time-month d)
                 (decoded-time-year d))))

(defun test--make-timed-event (time)
  "Make an event alist with a single timed timestamp at TIME."
  (let ((ts (test-timestamp-string time)))
    `((times . ((,ts . ,time))))))

(defun test--make-all-day-event (time)
  "Make an event alist with a single all-day timestamp at TIME."
  (let ((ts (test-timestamp-string time t)))
    `((times . ((,ts . nil))))))

;;; Normal Cases

(ert-deftest test-chime--event-is-today-timed-event-today ()
  "A timed event happening today should return truthy."
  (let ((event (test--make-timed-event (test--real-today-at 14 30))))
    (should (chime--event-is-today event))))

(ert-deftest test-chime--event-is-today-all-day-event-today ()
  "An all-day event for today should return truthy."
  (let ((event (test--make-all-day-event (test--real-today-at 0 0))))
    (should (chime--event-is-today event))))

(ert-deftest test-chime--event-is-today-yesterday-returns-nil ()
  "An event from yesterday should return nil."
  (let ((event (test--make-timed-event (test--real-yesterday-at 14 30))))
    (should-not (chime--event-is-today event))))

(ert-deftest test-chime--event-is-today-tomorrow-returns-nil ()
  "An event for tomorrow should return nil."
  (let ((event (test--make-timed-event (test--real-tomorrow-at 14 30))))
    (should-not (chime--event-is-today event))))

(ert-deftest test-chime--event-is-today-past-timed-event-today ()
  "A timed event earlier today (in the past) should return truthy."
  (let ((event (test--make-timed-event (test--real-today-at 0 1))))
    (should (chime--event-is-today event))))

(ert-deftest test-chime--event-is-today-future-timed-event-today ()
  "A timed event later today (in the future) should return truthy."
  (let ((event (test--make-timed-event (test--real-today-at 23 58))))
    (should (chime--event-is-today event))))

;;; Boundary Cases

(ert-deftest test-chime--event-is-today-event-at-2359-today ()
  "An event at 23:59 today should return truthy."
  (let ((event (test--make-timed-event (test--real-today-at 23 59))))
    (should (chime--event-is-today event))))

(ert-deftest test-chime--event-is-today-event-at-0000-today ()
  "An event at 00:00 today should return truthy."
  (let ((event (test--make-timed-event (test--real-today-at 0 0))))
    (should (chime--event-is-today event))))

;;; Error Cases

(ert-deftest test-chime--event-is-today-empty-times-returns-nil ()
  "An event with no times should return nil."
  (let ((event '((times . ()))))
    (should-not (chime--event-is-today event))))

(provide 'test-chime--event-is-today)
;;; test-chime--event-is-today.el ends here
