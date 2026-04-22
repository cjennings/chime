;;; test-chime-async-helpers.el --- Tests for async result helpers -*- lexical-binding: t; -*-

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

;; Unit tests for the async-result helpers used inside
;; chime--fetch-and-process:
;;   - chime--record-async-failure
;;   - chime--handle-async-success

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Setup and Teardown

(defun test-chime-async-helpers-setup ()
  "Reset counters and modeline state before each test."
  (setq chime--consecutive-async-failures 0)
  (setq chime-max-consecutive-failures 5)
  (setq chime-modeline-no-events-text "*")
  (setq chime-modeline-string nil))

(defun test-chime-async-helpers-teardown ()
  "Restore default state after each test."
  (setq chime--consecutive-async-failures 0)
  (setq chime-max-consecutive-failures 5)
  (setq chime-modeline-string nil))

;;;; Tests for chime--record-async-failure

(ert-deftest test-chime-record-async-failure-normal-increments-counter ()
  "Normal: each call increments the consecutive-failure counter by one."
  (test-chime-async-helpers-setup)
  (unwind-protect
      (let ((err '(error "boom")))
        (chime--record-async-failure err "Async error")
        (should (= 1 chime--consecutive-async-failures))
        (chime--record-async-failure err "Async error")
        (should (= 2 chime--consecutive-async-failures)))
    (test-chime-async-helpers-teardown)))

(ert-deftest test-chime-record-async-failure-normal-sets-modeline-error-state ()
  "Normal: sets chime-modeline-string with the standard error tooltip."
  (test-chime-async-helpers-setup)
  (unwind-protect
      (cl-letf (((symbol-function 'force-mode-line-update) (lambda (&optional _))))
        (chime--record-async-failure '(error "boom") "Async error")
        (should chime-modeline-string)
        (should (string-match-p "Event check failed"
                                (get-text-property 0 'help-echo chime-modeline-string))))
    (test-chime-async-helpers-teardown)))

(ert-deftest test-chime-record-async-failure-normal-warns-at-threshold ()
  "Normal: triggers display-warning when the counter reaches the threshold."
  (test-chime-async-helpers-setup)
  (unwind-protect
      (let ((warned nil))
        (setq chime--consecutive-async-failures 4)
        (setq chime-max-consecutive-failures 5)
        (cl-letf (((symbol-function 'display-warning)
                   (lambda (_type _msg &rest _args) (setq warned t)))
                  ((symbol-function 'force-mode-line-update) (lambda (&optional _))))
          (chime--record-async-failure '(error "boom") "Async error")
          (should warned)
          (should (= 5 chime--consecutive-async-failures))))
    (test-chime-async-helpers-teardown)))

(ert-deftest test-chime-record-async-failure-boundary-no-modeline-text-skips-modeline ()
  "Boundary: when chime-modeline-no-events-text is nil, modeline string stays nil."
  (test-chime-async-helpers-setup)
  (unwind-protect
      (let ((chime-modeline-no-events-text nil))
        (setq chime-modeline-string nil)
        (chime--record-async-failure '(error "boom") "Async error")
        (should (= 1 chime--consecutive-async-failures))
        (should (null chime-modeline-string)))
    (test-chime-async-helpers-teardown)))

;;;; Tests for chime--handle-async-success

(ert-deftest test-chime-handle-async-success-normal-resets-counter ()
  "Normal: resets the consecutive-failure counter from a positive value to zero."
  (test-chime-async-helpers-setup)
  (unwind-protect
      (let ((called-with nil))
        (setq chime--consecutive-async-failures 3)
        (chime--handle-async-success
         (lambda (events) (setq called-with events))
         '(event1 event2))
        (should (= 0 chime--consecutive-async-failures)))
    (test-chime-async-helpers-teardown)))

(ert-deftest test-chime-handle-async-success-normal-invokes-callback-with-events ()
  "Normal: calls the supplied callback with the events list."
  (test-chime-async-helpers-setup)
  (unwind-protect
      (let ((called-with 'unset))
        (chime--handle-async-success
         (lambda (events) (setq called-with events))
         '(a b c))
        (should (equal '(a b c) called-with)))
    (test-chime-async-helpers-teardown)))

(ert-deftest test-chime-handle-async-success-boundary-empty-events ()
  "Boundary: works with an empty events list."
  (test-chime-async-helpers-setup)
  (unwind-protect
      (let ((called-with 'unset))
        (chime--handle-async-success
         (lambda (events) (setq called-with events))
         '())
        (should (null called-with))
        (should (= 0 chime--consecutive-async-failures)))
    (test-chime-async-helpers-teardown)))

(ert-deftest test-chime-handle-async-success-boundary-counter-already-zero ()
  "Boundary: counter starts at zero, stays at zero, callback still fires."
  (test-chime-async-helpers-setup)
  (unwind-protect
      (let ((called-with 'unset))
        (setq chime--consecutive-async-failures 0)
        (chime--handle-async-success
         (lambda (events) (setq called-with events))
         '(x))
        (should (= 0 chime--consecutive-async-failures))
        (should (equal '(x) called-with)))
    (test-chime-async-helpers-teardown)))

(provide 'test-chime-async-helpers)
;;; test-chime-async-helpers.el ends here
