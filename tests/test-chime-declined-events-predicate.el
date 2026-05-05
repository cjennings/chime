;;; test-chime-declined-events-predicate.el --- Tests for chime-declined-events-predicate -*- lexical-binding: t; -*-

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

;; Tests for the predicate that filters out events the user declined in
;; their calendar.  org-gcal stores the attendee response in a `:STATUS:'
;; property; the values seen in real calendar exports are accepted,
;; declined, needs-action, and tentative.  Only "declined" should match.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;;; Normal Cases

(ert-deftest test-chime-declined-events-predicate-declined-status ()
  "Normal: an event whose STATUS property is `declined' returns non-nil."
  (with-temp-buffer
    (org-mode)
    (insert "* Meeting\n")
    (insert ":PROPERTIES:\n")
    (insert ":STATUS: declined\n")
    (insert ":END:\n")
    (insert "<2026-05-06 Wed 10:00>\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should (chime-declined-events-predicate marker)))))

(ert-deftest test-chime-declined-events-predicate-accepted-status ()
  "Normal: an event whose STATUS property is `accepted' returns nil."
  (with-temp-buffer
    (org-mode)
    (insert "* Meeting\n")
    (insert ":PROPERTIES:\n")
    (insert ":STATUS: accepted\n")
    (insert ":END:\n")
    (insert "<2026-05-06 Wed 10:00>\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should-not (chime-declined-events-predicate marker)))))

(ert-deftest test-chime-declined-events-predicate-tentative-status ()
  "Normal: tentative events still surface (only declined gets filtered)."
  (with-temp-buffer
    (org-mode)
    (insert "* Meeting\n")
    (insert ":PROPERTIES:\n")
    (insert ":STATUS: tentative\n")
    (insert ":END:\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should-not (chime-declined-events-predicate marker)))))

(ert-deftest test-chime-declined-events-predicate-needs-action-status ()
  "Normal: needs-action events still surface so the user can act on them."
  (with-temp-buffer
    (org-mode)
    (insert "* Meeting\n")
    (insert ":PROPERTIES:\n")
    (insert ":STATUS: needs-action\n")
    (insert ":END:\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should-not (chime-declined-events-predicate marker)))))

;;;; Boundary Cases

(ert-deftest test-chime-declined-events-predicate-no-status-property ()
  "Boundary: a heading with no STATUS property returns nil."
  (with-temp-buffer
    (org-mode)
    (insert "* Plain heading\n<2026-05-06 Wed 10:00>\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should-not (chime-declined-events-predicate marker)))))

(ert-deftest test-chime-declined-events-predicate-empty-status-property ()
  "Boundary: an empty STATUS property returns nil."
  (with-temp-buffer
    (org-mode)
    (insert "* Heading\n")
    (insert ":PROPERTIES:\n")
    (insert ":STATUS: \n")
    (insert ":END:\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should-not (chime-declined-events-predicate marker)))))

(ert-deftest test-chime-declined-events-predicate-declined-with-todo-keyword ()
  "Boundary: a declined event with a TODO keyword still matches."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Meeting\n")
    (insert ":PROPERTIES:\n")
    (insert ":STATUS: declined\n")
    (insert ":END:\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should (chime-declined-events-predicate marker)))))

(ert-deftest test-chime-declined-events-predicate-case-insensitive ()
  "Boundary: org-entry-get returns the value as written; uppercase
DECLINED does not match.  This documents the contract — the predicate
is case-sensitive because real org-gcal data uses lowercase verbatim."
  (with-temp-buffer
    (org-mode)
    (insert "* Meeting\n")
    (insert ":PROPERTIES:\n")
    (insert ":STATUS: DECLINED\n")
    (insert ":END:\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should-not (chime-declined-events-predicate marker)))))

;;;; Error Cases

(ert-deftest test-chime-declined-events-predicate-unrelated-status-value ()
  "Error: a STATUS value chime doesn't recognise returns nil rather
than treating it as declined."
  (with-temp-buffer
    (org-mode)
    (insert "* Meeting\n")
    (insert ":PROPERTIES:\n")
    (insert ":STATUS: gibberish\n")
    (insert ":END:\n")
    (goto-char (point-min))
    (let ((marker (point-marker)))
      (should-not (chime-declined-events-predicate marker)))))

;;;; Integration with the default predicate-blacklist

(ert-deftest test-chime-declined-events-predicate-on-default-blacklist ()
  "Normal: the predicate ships in the default `chime-predicate-blacklist'
so out-of-the-box installs hide declined events without extra config."
  (should (memq 'chime-declined-events-predicate
                (default-value 'chime-predicate-blacklist))))

(provide 'test-chime-declined-events-predicate)
;;; test-chime-declined-events-predicate.el ends here
