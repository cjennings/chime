;;; test-chime-extract-title.el --- Tests for chime--extract-title -*- lexical-binding: t; -*-

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

;; Unit tests for chime--extract-title function.
;; This function extracts the title from an org heading at a marker,
;; stripping TODO keywords, tags, and priority, then sanitizing the result.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;; Load test utilities
(require 'testutil-general (expand-file-name "testutil-general.el"))

;;; Normal Cases

(ert-deftest test-chime-extract-title-plain-heading ()
  "Plain heading should return just the title."
  (with-temp-buffer
    (org-mode)
    (insert "* Team Meeting\n")
    (goto-char (point-min))
    (should (string= "Team Meeting" (chime--extract-title (point-marker))))))

(ert-deftest test-chime-extract-title-todo-heading ()
  "TODO heading should strip the keyword, returning only the title."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Review PR\n")
    (goto-char (point-min))
    (should (string= "Review PR" (chime--extract-title (point-marker))))))

(ert-deftest test-chime-extract-title-heading-with-tags ()
  "Heading with tags should strip the tags."
  (with-temp-buffer
    (org-mode)
    (insert "* Team Meeting                                              :work:\n")
    (goto-char (point-min))
    (should (string= "Team Meeting" (chime--extract-title (point-marker))))))

(ert-deftest test-chime-extract-title-heading-with-priority ()
  "Heading with priority should strip the priority cookie."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO [#A] Urgent task\n")
    (goto-char (point-min))
    (should (string= "Urgent task" (chime--extract-title (point-marker))))))

(ert-deftest test-chime-extract-title-unicode ()
  "Heading with unicode characters should be preserved."
  (with-temp-buffer
    (org-mode)
    (insert "* Café meeting with André\n")
    (goto-char (point-min))
    (should (string= "Café meeting with André" (chime--extract-title (point-marker))))))

;;; Boundary Cases

(ert-deftest test-chime-extract-title-todo-only-heading ()
  "Heading with only a TODO keyword and no title text."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO\n")
    (goto-char (point-min))
    ;; Should return empty string (nil title is sanitized to "")
    (should (stringp (chime--extract-title (point-marker))))))

;;; Error Cases - Sanitization

(ert-deftest test-chime-extract-title-unmatched-paren ()
  "Title with unmatched parenthesis should be sanitized."
  (with-temp-buffer
    (org-mode)
    (insert "* Meeting (rescheduled\n")
    (goto-char (point-min))
    (let ((title (chime--extract-title (point-marker))))
      ;; Sanitizer should balance the paren
      (should (stringp title))
      (should (string-match-p "rescheduled" title))
      ;; Should have balanced parens
      (should (= (cl-count ?\( title)
                 (cl-count ?\) title))))))

(ert-deftest test-chime-extract-title-unmatched-bracket ()
  "Title with unmatched bracket should be sanitized."
  (with-temp-buffer
    (org-mode)
    (insert "* Review [draft\n")
    (goto-char (point-min))
    (let ((title (chime--extract-title (point-marker))))
      (should (stringp title))
      (should (= (cl-count ?\[ title)
                 (cl-count ?\] title))))))

(provide 'test-chime-extract-title)
;;; test-chime-extract-title.el ends here
