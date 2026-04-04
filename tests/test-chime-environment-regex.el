;;; test-chime-environment-regex.el --- Tests for chime-environment-regex -*- lexical-binding: t; -*-

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

;; Unit tests for chime-environment-regex function.
;; This function generates the regex used by async-inject-variables to
;; copy chime's config into the async subprocess.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Normal Cases

(ert-deftest test-chime-environment-regex-matches-default-variables ()
  "The generated regex should match all default chime variable names."
  (let ((regex (chime-environment-regex))
        (chime-additional-environment-regexes nil))
    (dolist (var '("org-agenda-files" "load-path" "org-todo-keywords"
                   "chime-alert-intervals" "chime-keyword-whitelist"
                   "chime-keyword-blacklist" "chime-tags-whitelist"
                   "chime-tags-blacklist" "chime-predicate-whitelist"
                   "chime-predicate-blacklist"))
      (should (string-match-p regex var)))))

(ert-deftest test-chime-environment-regex-includes-additional-regexes ()
  "With additional regexes configured, the result should match those too."
  (let ((chime-additional-environment-regexes '("my-custom-var")))
    (let ((regex (chime-environment-regex)))
      ;; Should still match defaults
      (should (string-match-p regex "org-agenda-files"))
      ;; Should also match the custom variable
      (should (string-match-p regex "my-custom-var")))))

;;; Boundary Cases

(ert-deftest test-chime-environment-regex-empty-additional-list ()
  "Empty additional regexes list should produce a valid regex matching defaults."
  (let ((chime-additional-environment-regexes nil))
    (let ((regex (chime-environment-regex)))
      (should (stringp regex))
      (should (string-match-p regex "chime-alert-intervals")))))

(provide 'test-chime-environment-regex)
;;; test-chime-environment-regex.el ends here
