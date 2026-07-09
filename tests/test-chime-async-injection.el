;;; test-chime-async-injection.el --- Tests for async environment injection -*- lexical-binding: t; -*-

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

;;; Commentary:

;; Tests that every chime defcustom the async child reads is injected into
;; the child by `chime--environment-regex'.
;;
;; The child calls (require 'chime), so an uninjected defcustom is still
;; *bound* there -- at its default.  A user who customizes it sees no error
;; and no effect, which is the worst shape a bug can take.  That is exactly
;; what happened to chime-tooltip-lookahead-hours: the docstring invites
;; 8760 "to see distant events", and the child kept fetching 168 hours.
;;
;; The load-bearing test walks the child form and fails on any chime
;; defcustom it reads that the regex doesn't cover, so a variable added to
;; the child later cannot reintroduce the bug quietly.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Helpers

(defun test-chime-injection--symbols (form)
  "Return every symbol appearing anywhere in FORM."
  (cond
   ((symbolp form) (and form (list form)))
   ((consp form) (append (test-chime-injection--symbols (car form))
                         (test-chime-injection--symbols (cdr form))))
   (t nil)))

(defun test-chime-injection--chime-defcustoms (form)
  "Return the chime defcustoms appearing in FORM, deduplicated."
  (seq-uniq
   (seq-filter (lambda (sym)
                 (and (custom-variable-p sym)
                      (string-prefix-p "chime-" (symbol-name sym))))
               (test-chime-injection--symbols form))))

;;; Normal Cases

(ert-deftest test-chime-async-injection-covers-every-chime-defcustom-in-the-child ()
  "Every chime defcustom the async child reads is injected into it.
An uninjected one silently runs at its default in the child, so a user's
customization is ignored without any error."
  (let* ((form (chime--retrieve-events))
         (regex (chime--environment-regex))
         (uncovered (seq-remove
                     (lambda (sym) (string-match-p regex (symbol-name sym)))
                     (test-chime-injection--chime-defcustoms form))))
    (should-not uncovered)))

(ert-deftest test-chime-async-injection-covers-the-lookahead-variables ()
  "Both lookahead variables reach the child.
The child sizes its agenda span from them, so without injection it fetches
the default 168-hour window no matter what the user set."
  (let ((regex (chime--environment-regex)))
    (should (string-match-p regex "chime-modeline-lookahead-minutes"))
    (should (string-match-p regex "chime-tooltip-lookahead-hours"))))

(ert-deftest test-chime-async-injection-covers-the-pre-existing-variables ()
  "The variables injected before the lookahead fix still are."
  (let ((regex (chime--environment-regex)))
    (dolist (name '("org-agenda-files" "load-path" "org-todo-keywords"
                    "chime-alert-intervals" "chime-include-filters"
                    "chime-exclude-filters"))
      (should (string-match-p regex name)))))

;;; Boundary Cases

(ert-deftest test-chime-async-injection-regex-is-anchored ()
  "The regex matches whole variable names, not substrings.
Without anchoring, a user's unrelated `my-org-agenda-files-backup' would
be swept into the child."
  (let ((regex (chime--environment-regex)))
    (should-not (string-match-p regex "my-org-agenda-files"))
    (should-not (string-match-p regex "org-agenda-files-extra"))))

(ert-deftest test-chime-async-injection-honors-additional-regexes ()
  "`chime-additional-environment-regexes' extends the injected set."
  (let* ((chime-additional-environment-regexes '("\\`my-var\\'"))
         (regex (chime--environment-regex)))
    (should (string-match-p regex "my-var"))
    (should (string-match-p regex "org-agenda-files"))))

(provide 'test-chime-async-injection)
;;; test-chime-async-injection.el ends here
