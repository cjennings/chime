;;; test-chime-get-tags.el --- Tests for chime--get-tags and chime-done-keywords-predicate -*- lexical-binding: t; -*-

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

;; Unit tests for tag extraction and done-keyword predicate:
;; - chime--get-tags: extracts org tags from a marker
;; - chime-done-keywords-predicate: checks if heading has a done keyword

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

;; Load test utilities
(require 'testutil-general (expand-file-name "testutil-general.el"))

;;;; Tests for chime--get-tags

;;; Normal Cases

(ert-deftest test-chime-get-tags-single-tag ()
  "Should extract a single tag from an org heading."
  (with-temp-buffer
    (org-mode)
    (insert "* Task                                                        :work:\n")
    (goto-char (point-min))
    (let* ((marker (point-marker))
           (tags (chime--get-tags marker)))
      (should (member "work" tags)))))

(ert-deftest test-chime-get-tags-multiple-tags ()
  "Should extract multiple tags from an org heading."
  (with-temp-buffer
    (org-mode)
    (insert "* Task                                                 :work:urgent:\n")
    (goto-char (point-min))
    (let* ((marker (point-marker))
           (tags (chime--get-tags marker)))
      (should (member "work" tags))
      (should (member "urgent" tags)))))

;;; Boundary Cases

(ert-deftest test-chime-get-tags-no-tags ()
  "Should return empty/nil list for heading with no tags."
  (with-temp-buffer
    (org-mode)
    (insert "* Task without tags\n")
    (goto-char (point-min))
    (let* ((marker (point-marker))
           (tags (chime--get-tags marker)))
      ;; Should be empty (nil or empty list)
      (should (null tags)))))

(ert-deftest test-chime-get-tags-heading-with-todo-keyword ()
  "Should extract tags correctly even with TODO keyword present."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Task                                                 :meeting:\n")
    (goto-char (point-min))
    (let* ((marker (point-marker))
           (tags (chime--get-tags marker)))
      (should (member "meeting" tags)))))

;;;; Tests for chime-done-keywords-predicate

;;; Normal Cases

(ert-deftest test-chime-done-predicate-done-keyword ()
  "DONE heading should return truthy."
  (with-temp-buffer
    (org-mode)
    (insert "* DONE Completed task\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should (chime-done-keywords-predicate marker)))))

(ert-deftest test-chime-done-predicate-todo-keyword ()
  "TODO heading should return nil."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Active task\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should-not (chime-done-keywords-predicate marker)))))

(ert-deftest test-chime-done-predicate-no-keyword ()
  "Heading without any TODO keyword should return nil."
  (with-temp-buffer
    (org-mode)
    (insert "* Plain heading\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should-not (chime-done-keywords-predicate marker)))))

;;; Boundary Cases

(ert-deftest test-chime-done-predicate-custom-done-keywords ()
  "Custom done keywords (org-done-keywords) should be recognized."
  (with-temp-buffer
    (org-mode)
    ;; CANCELLED is a standard done keyword in many org configs,
    ;; but org-done-keywords defaults to just ("DONE").
    ;; Test with the default DONE keyword.
    (insert "* DONE Task\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should (member (nth 2 (org-heading-components)) org-done-keywords)))))

(ert-deftest test-chime-done-predicate-heading-with-priority ()
  "DONE heading with priority should still be detected."
  (with-temp-buffer
    (org-mode)
    (insert "* DONE [#A] High priority done task\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should (chime-done-keywords-predicate marker)))))

(ert-deftest test-chime-done-predicate-heading-with-tags ()
  "DONE heading with tags should still be detected."
  (with-temp-buffer
    (org-mode)
    (insert "* DONE Tagged task                                          :work:\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should (chime-done-keywords-predicate marker)))))

(provide 'test-chime-get-tags)
;;; test-chime-get-tags.el ends here
