;;; test-bootstrap.el --- Common test initialization for chime -*- lexical-binding: t; -*-

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

;; Shared initialization for all chime test files.
;; Handles package setup, dependency loading, and chime initialization.
;;
;; Usage: (require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
;;
;; For debug tests, set chime-debug BEFORE requiring this file:
;;   (setq chime-debug t)
;;   (require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

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

;; Load the near-universal test helpers so individual test files don't each
;; repeat the require.  testutil-general carries the base-dir fixture used by
;; `chime-deftest' below; testutil-time carries the dynamic-time helpers.
(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))

(defmacro chime-deftest (name arglist &rest body)
  "Define an ERT test NAME with chime's standard base-dir fixture.
ARGLIST is the `ert-deftest' argument list (normally nil).  When the
first form in BODY is a string it is kept as the test docstring.  The
remaining forms run inside the test base directory, created beforehand
with `chime-create-test-base-dir' and removed afterward with
`chime-delete-test-base-dir' even if a form signals."
  (declare (indent 2) (doc-string 3))
  (let* ((doc (and (stringp (car body)) (cdr body) (car body)))
         (forms (if doc (cdr body) body)))
    `(ert-deftest ,name ,arglist
       ,@(and doc (list doc))
       (chime-create-test-base-dir)
       (unwind-protect
           (progn ,@forms)
         (chime-delete-test-base-dir)))))

(provide 'test-bootstrap)
;;; test-bootstrap.el ends here
