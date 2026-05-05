;;; test-chime-numeric-defcustom-setters.el --- Setter validation for numeric defcustoms -*- lexical-binding: t; -*-

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

;; The numeric defcustoms feed arithmetic (timer math, lookahead windows,
;; counters) and a bad value reaches the wrong layer if it slips past the
;; setter — the user gets an `arith-error' or a confusing timer failure
;; instead of a configuration error.  These tests pin down the contract:
;; bad values raise `user-error' at customize-time; valid values land.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;;; chime--validate-integer-setting helper

(ert-deftest test-chime-validate-integer-setting-accepts-valid-non-negative ()
  "Normal: 0 passes when MIN is 0."
  (should (eq 0 (chime--validate-integer-setting
                 'fake-symbol 0 0 nil))))

(ert-deftest test-chime-validate-integer-setting-rejects-non-integer ()
  "Error: a string raises `user-error' naming the symbol."
  (let ((err (should-error (chime--validate-integer-setting
                            'fake-symbol "ten" 0 nil)
                           :type 'user-error)))
    (should (string-match-p "fake-symbol" (cadr err)))))

(ert-deftest test-chime-validate-integer-setting-rejects-below-min ()
  "Error: a value below MIN raises `user-error'."
  (should-error (chime--validate-integer-setting
                 'fake-symbol 0 1 nil)
                :type 'user-error))

(ert-deftest test-chime-validate-integer-setting-allows-nil-when-permitted ()
  "Boundary: nil passes when ALLOW-NIL is non-nil."
  (should (null (chime--validate-integer-setting
                 'fake-symbol nil 0 t))))

(ert-deftest test-chime-validate-integer-setting-rejects-nil-when-not-permitted ()
  "Error: nil fails when ALLOW-NIL is nil."
  (should-error (chime--validate-integer-setting
                 'fake-symbol nil 0 nil)
                :type 'user-error))

;;;; chime-modeline-lookahead-minutes — integer >= 0

(ert-deftest test-chime-modeline-lookahead-minutes-accepts-zero ()
  "Normal: 0 is valid (disables modeline display)."
  (let ((chime-modeline-lookahead-minutes 120))
    (customize-set-variable 'chime-modeline-lookahead-minutes 0)
    (should (= 0 chime-modeline-lookahead-minutes))))

(ert-deftest test-chime-modeline-lookahead-minutes-rejects-negative ()
  "Error: negative integer raises."
  (let ((chime-modeline-lookahead-minutes 120))
    (should-error (customize-set-variable
                   'chime-modeline-lookahead-minutes -5)
                  :type 'user-error)))

(ert-deftest test-chime-modeline-lookahead-minutes-rejects-non-integer ()
  "Error: string raises."
  (let ((chime-modeline-lookahead-minutes 120))
    (should-error (customize-set-variable
                   'chime-modeline-lookahead-minutes "many")
                  :type 'user-error)))

;;;; chime-tooltip-lookahead-hours — integer >= 1

(ert-deftest test-chime-tooltip-lookahead-hours-accepts-positive ()
  "Normal: 1 is the floor."
  (let ((chime-tooltip-lookahead-hours 168))
    (customize-set-variable 'chime-tooltip-lookahead-hours 1)
    (should (= 1 chime-tooltip-lookahead-hours))))

(ert-deftest test-chime-tooltip-lookahead-hours-rejects-zero ()
  "Error: 0 hours of lookahead would never find anything."
  (let ((chime-tooltip-lookahead-hours 168))
    (should-error (customize-set-variable
                   'chime-tooltip-lookahead-hours 0)
                  :type 'user-error)))

(ert-deftest test-chime-tooltip-lookahead-hours-rejects-negative ()
  "Error: negative integer raises."
  (let ((chime-tooltip-lookahead-hours 168))
    (should-error (customize-set-variable
                   'chime-tooltip-lookahead-hours -1)
                  :type 'user-error)))

;;;; chime-modeline-tooltip-max-events — nil or integer >= 1

(ert-deftest test-chime-modeline-tooltip-max-events-accepts-nil ()
  "Boundary: nil means show all (per docstring)."
  (let ((chime-modeline-tooltip-max-events 5))
    (customize-set-variable 'chime-modeline-tooltip-max-events nil)
    (should (null chime-modeline-tooltip-max-events))))

(ert-deftest test-chime-modeline-tooltip-max-events-accepts-positive ()
  "Normal: 1 is the floor when set."
  (let ((chime-modeline-tooltip-max-events 5))
    (customize-set-variable 'chime-modeline-tooltip-max-events 1)
    (should (= 1 chime-modeline-tooltip-max-events))))

(ert-deftest test-chime-modeline-tooltip-max-events-rejects-zero ()
  "Error: 0 events makes the tooltip empty by config rather than nil."
  (let ((chime-modeline-tooltip-max-events 5))
    (should-error (customize-set-variable
                   'chime-modeline-tooltip-max-events 0)
                  :type 'user-error)))

;;;; chime-day-wide-advance-notice — nil or integer >= 0

(ert-deftest test-chime-day-wide-advance-notice-accepts-nil ()
  "Boundary: nil means same-day only (per docstring)."
  (let ((chime-day-wide-advance-notice 1))
    (customize-set-variable 'chime-day-wide-advance-notice nil)
    (should (null chime-day-wide-advance-notice))))

(ert-deftest test-chime-day-wide-advance-notice-accepts-zero ()
  "Boundary: 0 is the floor (same-day only) when set."
  (let ((chime-day-wide-advance-notice nil))
    (customize-set-variable 'chime-day-wide-advance-notice 0)
    (should (= 0 chime-day-wide-advance-notice))))

(ert-deftest test-chime-day-wide-advance-notice-rejects-negative ()
  "Error: negative-day advance notice is meaningless."
  (let ((chime-day-wide-advance-notice nil))
    (should-error (customize-set-variable
                   'chime-day-wide-advance-notice -1)
                  :type 'user-error)))

;;;; chime-max-consecutive-failures — integer >= 0

(ert-deftest test-chime-max-consecutive-failures-accepts-zero ()
  "Normal: 0 disables failure warnings (per docstring)."
  (let ((chime-max-consecutive-failures 5))
    (customize-set-variable 'chime-max-consecutive-failures 0)
    (should (= 0 chime-max-consecutive-failures))))

(ert-deftest test-chime-max-consecutive-failures-rejects-negative ()
  "Error: negative threshold is meaningless."
  (let ((chime-max-consecutive-failures 5))
    (should-error (customize-set-variable
                   'chime-max-consecutive-failures -1)
                  :type 'user-error)))

;;;; chime-validation-max-retries — integer >= 0

(ert-deftest test-chime-validation-max-retries-accepts-zero ()
  "Normal: 0 means show errors immediately without retrying (per docstring)."
  (let ((chime-validation-max-retries 3))
    (customize-set-variable 'chime-validation-max-retries 0)
    (should (= 0 chime-validation-max-retries))))

(ert-deftest test-chime-validation-max-retries-accepts-positive ()
  "Normal: positive integer is valid."
  (let ((chime-validation-max-retries 3))
    (customize-set-variable 'chime-validation-max-retries 5)
    (should (= 5 chime-validation-max-retries))))

(ert-deftest test-chime-validation-max-retries-rejects-negative ()
  "Error: negative retry count is meaningless."
  (let ((chime-validation-max-retries 3))
    (should-error (customize-set-variable
                   'chime-validation-max-retries -1)
                  :type 'user-error)))

(provide 'test-chime-numeric-defcustom-setters)
;;; test-chime-numeric-defcustom-setters.el ends here
