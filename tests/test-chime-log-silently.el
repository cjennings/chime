;;; test-chime-log-silently.el --- Tests for chime--log-silently -*- lexical-binding: t; -*-

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

;; Unit tests for chime--log-silently function.
;; This function writes to *Messages* buffer without echoing to minibuffer.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Normal Cases

(ert-deftest test-chime-log-silently-writes-to-messages ()
  "Should write the formatted text to *Messages* buffer."
  (let ((messages-buf (get-buffer-create "*Messages*")))
    (with-current-buffer messages-buf
      (let ((pos-before (point-max)))
        (chime--log-silently "Test log message")
        (goto-char pos-before)
        (should (search-forward "Test log message" nil t))))))

(ert-deftest test-chime-log-silently-formats-with-args ()
  "Should format with args like `format'."
  (let ((messages-buf (get-buffer-create "*Messages*")))
    (with-current-buffer messages-buf
      (let ((pos-before (point-max)))
        (chime--log-silently "Event count: %d, name: %s" 5 "Meeting")
        (goto-char pos-before)
        (should (search-forward "Event count: 5, name: Meeting" nil t))))))

(ert-deftest test-chime-log-silently-multiple-calls-append ()
  "Multiple calls should append sequentially."
  (let ((messages-buf (get-buffer-create "*Messages*")))
    (with-current-buffer messages-buf
      (let ((pos-before (point-max)))
        (chime--log-silently "First message")
        (chime--log-silently "Second message")
        (goto-char pos-before)
        (let ((first-pos (search-forward "First message" nil t))
              (second-pos (progn (goto-char pos-before)
                                 (search-forward "Second message" nil t))))
          (should first-pos)
          (should second-pos)
          ;; Second should come after first
          (should (> second-pos first-pos)))))))

;;; Boundary Cases

(ert-deftest test-chime-log-silently-empty-format-string ()
  "Empty format string should not error."
  ;; Should not signal an error
  (should-not (condition-case nil
                  (progn (chime--log-silently "") nil)
                (error t))))

(provide 'test-chime-log-silently)
;;; test-chime-log-silently.el ends here
