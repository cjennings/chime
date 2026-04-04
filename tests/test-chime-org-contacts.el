;;; test-chime-org-contacts.el --- Tests for chime-org-contacts.el -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Craig Jennings

;; Author: Craig Jennings <c@cjennings.net>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Unit and integration tests for chime-org-contacts.el

;;; Code:

;; Initialize package system for batch mode
(when noninteractive
  (package-initialize))

(require 'ert)
(require 'org)
(require 'org-capture)

;; Load the conversion module (shared birthday utilities)
(load (expand-file-name "../convert-org-contacts-birthdays.el"
                        (file-name-directory (or load-file-name buffer-file-name))) nil t)

;; Load the module being tested
(let ((module-file (expand-file-name "../chime-org-contacts.el"
                                     (file-name-directory (or load-file-name buffer-file-name)))))
  (load module-file nil t))

;;; Integration Tests - chime-org-contacts--finalize-birthday-timestamp

(ert-deftest test-chime-org-contacts-finalize-adds-timestamp-full-date ()
  "Test finalize adds timestamp for YYYY-MM-DD birthday."
  (with-temp-buffer
    (org-mode)
    (insert "* Alice Anderson\n")
    (insert ":PROPERTIES:\n")
    (insert ":EMAIL: alice@example.com\n")
    (insert ":BIRTHDAY: 1985-03-15\n")
    (insert ":END:\n")
    (goto-char (point-min))

    (let ((org-capture-plist '(:key "C")))
      (chime-org-contacts--finalize-birthday-timestamp)

      (let ((content (buffer-string)))
        (should (string-match-p "<1985-03-15 [A-Za-z]\\{3\\} \\+1y>" content))))))

(ert-deftest test-chime-org-contacts-finalize-adds-timestamp-partial-date ()
  "Test finalize adds timestamp for MM-DD birthday."
  (let ((current-year (nth 5 (decode-time))))
    (with-temp-buffer
      (org-mode)
      (insert "* Bob Baker\n")
      (insert ":PROPERTIES:\n")
      (insert ":BIRTHDAY: 07-04\n")
      (insert ":END:\n")
      (goto-char (point-min))

      (let ((org-capture-plist '(:key "C")))
        (chime-org-contacts--finalize-birthday-timestamp)

        (let ((content (buffer-string)))
          (should (string-match-p (format "<%d-07-04 [A-Za-z]\\{3\\} \\+1y>" current-year) content)))))))

(ert-deftest test-chime-org-contacts-finalize-skips-when-no-birthday ()
  "Test finalize does nothing when :BIRTHDAY: property missing."
  (with-temp-buffer
    (org-mode)
    (insert "* Carol Chen\n")
    (insert ":PROPERTIES:\n")
    (insert ":EMAIL: carol@example.com\n")
    (insert ":END:\n")
    (goto-char (point-min))

    (let ((original-content (buffer-string))
          (org-capture-plist '(:key "C")))
      (chime-org-contacts--finalize-birthday-timestamp)

      ;; Content should be unchanged
      (should (string= (buffer-string) original-content)))))

(ert-deftest test-chime-org-contacts-finalize-skips-empty-birthday ()
  "Test finalize skips empty birthday values."
  (with-temp-buffer
    (org-mode)
    (insert "* David Davis\n")
    (insert ":PROPERTIES:\n")
    (insert ":BIRTHDAY: \n")
    (insert ":END:\n")
    (goto-char (point-min))

    (let ((original-content (buffer-string))
          (org-capture-plist '(:key "C")))
      (chime-org-contacts--finalize-birthday-timestamp)

      (should (string= (buffer-string) original-content)))))

(ert-deftest test-chime-org-contacts-finalize-only-runs-for-correct-key ()
  "Test finalize only runs for configured capture key."
  (with-temp-buffer
    (org-mode)
    (insert "* Task\n")
    (insert ":PROPERTIES:\n")
    (insert ":BIRTHDAY: 2000-01-01\n")
    (insert ":END:\n")
    (goto-char (point-min))

    (let ((original-content (buffer-string))
          (org-capture-plist '(:key "t")))  ; Different key
      (chime-org-contacts--finalize-birthday-timestamp)

      ;; Should not insert timestamp
      (should (string= (buffer-string) original-content)))))

;;; Integration Tests - chime-org-contacts--setup-capture-template

(ert-deftest test-chime-org-contacts-setup-adds-template-when-file-set ()
  "Test that template is added when file is set."
  (let ((chime-org-contacts-file "/tmp/test-contacts.org")
        (org-capture-templates nil))

    (chime-org-contacts--setup-capture-template)

    (should org-capture-templates)
    (should (assoc "C" org-capture-templates))))

(ert-deftest test-chime-org-contacts-setup-skips-when-file-nil ()
  "Test that template is not added when file is nil."
  (let ((chime-org-contacts-file nil)
        (org-capture-templates nil))

    (chime-org-contacts--setup-capture-template)

    (should-not org-capture-templates)))

(ert-deftest test-chime-org-contacts-setup-template-structure ()
  "Test that added template has correct structure."
  (let ((chime-org-contacts-file "/tmp/test-contacts.org")
        (chime-org-contacts-capture-key "C")
        (chime-org-contacts-heading "Contacts")
        (org-capture-templates nil))

    (chime-org-contacts--setup-capture-template)

    (let ((template (assoc "C" org-capture-templates)))
      (should (string= (nth 1 template) "Contact (chime)"))
      (should (eq (nth 2 template) 'entry))
      (should (equal (nth 3 template) '(file+headline chime-org-contacts-file "Contacts"))))))

(ert-deftest test-chime-org-contacts-setup-uses-custom-key ()
  "Test that template uses custom capture key."
  (let ((chime-org-contacts-file "/tmp/test-contacts.org")
        (chime-org-contacts-capture-key "K")
        (org-capture-templates nil))

    (chime-org-contacts--setup-capture-template)

    (should (assoc "K" org-capture-templates))
    (should-not (assoc "C" org-capture-templates))))

(provide 'test-chime-org-contacts)
;;; test-chime-org-contacts.el ends here
