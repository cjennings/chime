;;; test-chime-event-contract.el --- Tests for Chime event alist contract -*- lexical-binding: t; -*-

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

;; Unit tests for the explicit internal event alist contract.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

(require 'testutil-events (expand-file-name "testutil-events.el"))

(ert-deftest test-chime-event-contract-make-event-creates-valid-event ()
  "Constructor returns an event matching the documented contract."
  (let* ((event-time (test-time-tomorrow-at 9 30))
         (timestamp (test-timestamp-string event-time))
         (event (chime--make-event
                 (list (cons timestamp event-time))
                 "Planning"
                 '((10 . medium) (0 . high))
                 "/tmp/chime-test.org"
                 42)))
    (should (chime--valid-event-p event))
    (should (equal (list (cons timestamp event-time))
                   (chime--event-times event)))
    (should (string= "Planning" (chime--event-title event)))
    (should (equal '((10 . medium) (0 . high))
                   (chime--event-intervals event)))
    (should (string= "/tmp/chime-test.org"
                     (chime--event-marker-file event)))
    (should (= 42 (chime--event-marker-pos event)))))

(ert-deftest test-chime-event-contract-validates-all-day-timestamps ()
  "All-day timestamps are valid when their parsed time value is nil."
  (let ((event (chime--make-event
                '(("<2026-05-11 Mon>" . nil))
                "All Day"
                '((10 . medium)))))
    (should (chime--valid-event-p event))))

(ert-deftest test-chime-event-contract-rejects-missing-required-keys ()
  "Validator rejects event alists missing required keys."
  (should-not (chime--valid-event-p
               '((times . nil)
                 (intervals . ((10 . medium)))))))

(ert-deftest test-chime-event-contract-rejects-malformed-time-entry ()
  "Constructor rejects malformed timestamp entries."
  (should-error
   (chime--make-event
    '((not-a-string . nil))
    "Bad Time"
    '((10 . medium)))))

(ert-deftest test-chime-event-contract-rejects-malformed-interval-entry ()
  "Constructor rejects malformed alert intervals."
  (should-error
   (chime--make-event
    '(("<2026-05-11 Mon 09:30>" . nil))
    "Bad Interval"
    '((10 . urgent)))))

(ert-deftest test-chime-event-contract-rejects-malformed-marker-identity ()
  "Constructor rejects partial or wrongly typed marker identity values."
  (should-error
   (chime--make-event
    '(("<2026-05-11 Mon 09:30>" . nil))
    "Bad Marker"
    '((10 . medium))
    "/tmp/chime-test.org"
    "42")))

(ert-deftest test-chime-event-contract-test-builder-uses-valid-shape ()
  "Shared test event builder emits contract-valid event alists."
  (let ((event (test-make-simple-event
                "Builder Event"
                (test-time-tomorrow-at 11 0)
                5
                'low)))
    (should (chime--valid-event-p event))
    (should (string= "Builder Event" (chime--event-title event)))))

(provide 'test-chime-event-contract)
;;; test-chime-event-contract.el ends here
