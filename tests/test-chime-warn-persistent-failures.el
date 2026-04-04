;;; test-chime-warn-persistent-failures.el --- Tests for chime--maybe-warn-persistent-failures -*- lexical-binding: t; -*-

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

;; Unit tests for chime--maybe-warn-persistent-failures function.
;; This function warns the user when consecutive async failures reach
;; the configured threshold. It should warn exactly once at the threshold.

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

;;; Setup and Teardown

(defun test-warn-failures-setup ()
  "Setup function."
  (setq chime--consecutive-async-failures 0)
  (setq chime-max-consecutive-failures 5))

(defun test-warn-failures-teardown ()
  "Teardown function."
  (setq chime--consecutive-async-failures 0)
  (setq chime-max-consecutive-failures 5))

;;; Normal Cases

(ert-deftest test-chime-warn-failures-warns-at-threshold ()
  "Should call display-warning when failures reach the threshold."
  (test-warn-failures-setup)
  (unwind-protect
      (let ((warned nil))
        (setq chime--consecutive-async-failures 5)
        (setq chime-max-consecutive-failures 5)
        (cl-letf (((symbol-function 'display-warning)
                   (lambda (_type _msg &rest _args) (setq warned t))))
          (chime--maybe-warn-persistent-failures)
          (should warned)))
    (test-warn-failures-teardown)))

(ert-deftest test-chime-warn-failures-no-warn-below-threshold ()
  "Should NOT warn when failures are below the threshold."
  (test-warn-failures-setup)
  (unwind-protect
      (let ((warned nil))
        (setq chime--consecutive-async-failures 4)
        (setq chime-max-consecutive-failures 5)
        (cl-letf (((symbol-function 'display-warning)
                   (lambda (_type _msg &rest _args) (setq warned t))))
          (chime--maybe-warn-persistent-failures)
          (should-not warned)))
    (test-warn-failures-teardown)))

(ert-deftest test-chime-warn-failures-no-warn-above-threshold ()
  "Should NOT warn again after exceeding the threshold (warns once)."
  (test-warn-failures-setup)
  (unwind-protect
      (let ((warned nil))
        (setq chime--consecutive-async-failures 6)
        (setq chime-max-consecutive-failures 5)
        (cl-letf (((symbol-function 'display-warning)
                   (lambda (_type _msg &rest _args) (setq warned t))))
          (chime--maybe-warn-persistent-failures)
          (should-not warned)))
    (test-warn-failures-teardown)))

(ert-deftest test-chime-warn-failures-message-includes-count ()
  "Warning message should include the failure count."
  (test-warn-failures-setup)
  (unwind-protect
      (let ((warning-msg nil))
        (setq chime--consecutive-async-failures 5)
        (setq chime-max-consecutive-failures 5)
        (cl-letf (((symbol-function 'display-warning)
                   (lambda (_type msg &rest _args) (setq warning-msg msg))))
          (chime--maybe-warn-persistent-failures)
          (should warning-msg)
          (should (string-match-p "5" warning-msg))))
    (test-warn-failures-teardown)))

(ert-deftest test-chime-warn-failures-severity-is-warning ()
  "Warning should use :warning severity."
  (test-warn-failures-setup)
  (unwind-protect
      (let ((warning-severity nil))
        (setq chime--consecutive-async-failures 5)
        (setq chime-max-consecutive-failures 5)
        (cl-letf (((symbol-function 'display-warning)
                   (lambda (_type _msg &rest args) (setq warning-severity (car args)))))
          (chime--maybe-warn-persistent-failures)
          (should (eq :warning warning-severity))))
    (test-warn-failures-teardown)))

;;; Boundary Cases

(ert-deftest test-chime-warn-failures-threshold-of-1 ()
  "Threshold of 1 should warn on the very first failure."
  (test-warn-failures-setup)
  (unwind-protect
      (let ((warned nil))
        (setq chime--consecutive-async-failures 1)
        (setq chime-max-consecutive-failures 1)
        (cl-letf (((symbol-function 'display-warning)
                   (lambda (_type _msg &rest _args) (setq warned t))))
          (chime--maybe-warn-persistent-failures)
          (should warned)))
    (test-warn-failures-teardown)))

(ert-deftest test-chime-warn-failures-threshold-of-0-disables ()
  "Threshold of 0 should disable warnings entirely."
  (test-warn-failures-setup)
  (unwind-protect
      (let ((warned nil))
        (setq chime--consecutive-async-failures 0)
        (setq chime-max-consecutive-failures 0)
        (cl-letf (((symbol-function 'display-warning)
                   (lambda (_type _msg &rest _args) (setq warned t))))
          (chime--maybe-warn-persistent-failures)
          (should-not warned)))
    (test-warn-failures-teardown)))

(ert-deftest test-chime-warn-failures-zero-failures-no-warn ()
  "Zero failures should never warn regardless of threshold."
  (test-warn-failures-setup)
  (unwind-protect
      (let ((warned nil))
        (setq chime--consecutive-async-failures 0)
        (setq chime-max-consecutive-failures 5)
        (cl-letf (((symbol-function 'display-warning)
                   (lambda (_type _msg &rest _args) (setq warned t))))
          (chime--maybe-warn-persistent-failures)
          (should-not warned)))
    (test-warn-failures-teardown)))

(provide 'test-chime-warn-persistent-failures)
;;; test-chime-warn-persistent-failures.el ends here
