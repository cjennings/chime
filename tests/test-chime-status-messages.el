;;; test-chime-status-messages.el --- Tests for customizable status messages -*- lexical-binding: t; -*-

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

;; Verify that the status-message defcustoms control the strings shown to
;; the user in *Messages* and in the modeline help-echo.  Existing tests
;; in test-chime-validate-configuration.el and test-chime-validation-retry.el
;; cover the default text; this file proves the wiring honors customization.
;;
;; Mocks are kept in a single cl-letf per test to avoid native-comp
;; trampoline issues with nested redefinitions of subrs like `message'.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'cl-lib)

(defmacro test-chime-status--with-validation-state (&rest body)
  "Run BODY with isolated chime validation/modeline state."
  (declare (indent 0) (debug t))
  `(let ((chime--validation-done nil)
         (chime--validation-retry-count 0)
         (chime--validation-max-retries 3)
         (chime--consecutive-async-failures 0)
         (chime-modeline-string nil)
         (chime-modeline-no-events-text " ⏰"))
     ,@body))

(defun test-chime-status--tooltip-string (modeline-string)
  "Return the `help-echo' property from MODELINE-STRING, or nil."
  (and modeline-string
       (get-text-property 0 'help-echo modeline-string)))

;;; Interactive validation banner and summary

(ert-deftest test-chime-validating-message-uses-defcustom ()
  "Normal: custom validating banner appears in *Messages* during interactive validate."
  (let ((chime-validating-message "CUSTOM validating banner")
        (org-agenda-files '("/tmp/exists.org"))
        (chime-enable-modeline t)
        (global-mode-string '(""))
        (messages nil))
    (cl-letf (((symbol-function 'file-exists-p) (lambda (_) t))
              ((symbol-function 'require) (lambda (_ &optional _ _) t))
              ((symbol-function 'called-interactively-p) (lambda (_) t))
              ((symbol-function 'message)
               (lambda (format-string &rest args)
                 (push (apply #'format format-string args) messages))))
      (chime-validate-configuration))
    (should (member "CUSTOM validating banner" (nreverse messages)))))

(ert-deftest test-chime-validation-summary-format-uses-defcustom ()
  "Normal: custom summary format controls the count summary in *Messages*."
  (let ((chime-validation-summary-format "summary errs=%d%s warns=%d%s")
        (org-agenda-files '("/tmp/exists.org"))
        (chime-enable-modeline t)
        (global-mode-string '(""))
        (messages nil))
    (cl-letf (((symbol-function 'file-exists-p) (lambda (_) t))
              ((symbol-function 'require) (lambda (_ &optional _ _) t))
              ((symbol-function 'called-interactively-p) (lambda (_) t))
              ((symbol-function 'message)
               (lambda (format-string &rest args)
                 (push (apply #'format format-string args) messages))))
      (chime-validate-configuration))
    (should (member "summary errs=0s warns=0s" (nreverse messages)))))

;;; Async failure tooltip

(ert-deftest test-chime-async-failure-tooltip-uses-defcustom ()
  "Normal: async-failure tooltip uses the configured string."
  (test-chime-status--with-validation-state
    (let ((chime-async-failure-tooltip "CUSTOM async fail")
          (chime-max-consecutive-failures 0))
      (chime--record-async-failure '(error "boom") "Async error")
      (should (string-match-p
               "CUSTOM async fail"
               (test-chime-status--tooltip-string chime-modeline-string))))))

;;; Validation retry: errors-message + error tooltip (retries exhausted)

(ert-deftest test-chime-validation-errors-message-uses-defcustom ()
  "Normal: errors-exhausted banner uses the configured string."
  (test-chime-status--with-validation-state
    (let ((chime-validation-errors-message "CUSTOM errors detected")
          (org-agenda-files nil)
          (messages nil))
      (setq chime--validation-retry-count 99)
      (setq chime--validation-max-retries 0)
      (cl-letf (((symbol-function 'message)
                 (lambda (format-string &rest args)
                   (push (apply #'format format-string args) messages))))
        (chime--maybe-validate))
      (should (member "CUSTOM errors detected" (nreverse messages))))))

(ert-deftest test-chime-validation-error-tooltip-uses-defcustom ()
  "Normal: errors-exhausted tooltip uses the configured string."
  (test-chime-status--with-validation-state
    (let ((chime-validation-error-tooltip "CUSTOM error tip")
          (org-agenda-files nil))
      (setq chime--validation-retry-count 99)
      (setq chime--validation-max-retries 0)
      (cl-letf (((symbol-function 'message) (lambda (&rest _) nil)))
        (chime--maybe-validate))
      (should (string-match-p
               "CUSTOM error tip"
               (test-chime-status--tooltip-string chime-modeline-string))))))

;;; Validation retry: waiting-message + waiting-tooltip (retry in progress)

(ert-deftest test-chime-validation-waiting-message-format-uses-defcustom ()
  "Normal: retry banner uses the configured format with attempt/max."
  (test-chime-status--with-validation-state
    (let ((chime-validation-waiting-message-format "waiting %d of %d")
          (org-agenda-files nil)
          (messages nil))
      (setq chime--validation-retry-count 0)
      (setq chime--validation-max-retries 3)
      (cl-letf (((symbol-function 'message)
                 (lambda (format-string &rest args)
                   (push (apply #'format format-string args) messages))))
        (chime--maybe-validate))
      (should (member "waiting 1 of 3" (nreverse messages))))))

(ert-deftest test-chime-validation-waiting-tooltip-format-uses-defcustom ()
  "Normal: retry tooltip uses the configured format with attempt/max."
  (test-chime-status--with-validation-state
    (let ((chime-validation-waiting-tooltip-format "wait %d %d")
          (org-agenda-files nil))
      (setq chime--validation-retry-count 0)
      (setq chime--validation-max-retries 3)
      (cl-letf (((symbol-function 'message) (lambda (&rest _) nil)))
        (chime--maybe-validate))
      (should (string-match-p
               "wait 1 3"
               (test-chime-status--tooltip-string chime-modeline-string))))))

;;; Initial modeline tooltip (before first check)

(ert-deftest test-chime-modeline-initial-tooltip-uses-defcustom ()
  "Normal: initial modeline tooltip uses the configured string."
  (let ((chime-modeline-initial-tooltip "CUSTOM initial tip")
        (chime-modeline-no-events-text " ⏰"))
    (should (string-match-p
             "CUSTOM initial tip"
             (test-chime-status--tooltip-string
              (chime--make-initial-modeline-string))))))

(provide 'test-chime-status-messages)
;;; test-chime-status-messages.el ends here
