;;; test-chime-jump-to-event.el --- Tests for chime--jump-to-event navigation -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;; Author: Craig Jennings <c@cjennings.net>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Unit tests for `chime--jump-to-event'.  The function reconstructs an
;; org buffer position from the serialized marker-file + marker-pos pair
;; that survives the async boundary, opens the file, moves point, and
;; reveals the entry.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-general (expand-file-name "testutil-general.el"))

(defun test-chime-jump-to-event--make-temp-org-file (content)
  "Write CONTENT to a temp .org file under the test base dir and return its path."
  (let* ((base (chime-create-test-base-dir))
         (path (expand-file-name
                (concat (make-temp-name "jump-to-event-") ".org")
                base)))
    (with-temp-file path
      (insert content))
    path))

(ert-deftest test-chime-jump-to-event-normal-opens-file-and-moves-point ()
  "Normal: opens the event's file and moves point to the recorded position."
  (unwind-protect
      (let* ((content "* First heading
some body

* Target heading
target body
")
             (file (test-chime-jump-to-event--make-temp-org-file content))
             (target-pos (with-temp-buffer
                           (insert-file-contents file)
                           (goto-char (point-min))
                           (search-forward "* Target heading")
                           (line-beginning-position)))
             (event (chime--make-event
                     '(("<2026-05-10 Sun 09:30>" . (26760 32460)))
                     "Target heading"
                     '((0 . medium))
                     file
                     target-pos))
             (buffer-before-jump nil))
        (unwind-protect
            (progn
              (setq buffer-before-jump (current-buffer))
              (chime--jump-to-event event)
              (should (string= file (buffer-file-name)))
              (should (= target-pos (point))))
          (when (and (get-file-buffer file))
            (kill-buffer (get-file-buffer file)))
          (when (buffer-live-p buffer-before-jump)
            (switch-to-buffer buffer-before-jump))))
    (chime-delete-test-base-dir)))

(ert-deftest test-chime-jump-to-event-boundary-nil-marker-file-no-op ()
  "Boundary: an event with nil marker-file does nothing (no error, no jump)."
  (let* ((event (chime--make-event
                 '(("<2026-05-10 Sun 09:30>" . (26760 32460)))
                 "No File"
                 '((0 . medium))
                 nil
                 123))
         (buffer-before (current-buffer)))
    (chime--jump-to-event event)
    (should (eq buffer-before (current-buffer)))))

(ert-deftest test-chime-jump-to-event-boundary-missing-file-no-op ()
  "Boundary: when the recorded file no longer exists, the jump is a no-op."
  (let* ((event (chime--make-event
                 '(("<2026-05-10 Sun 09:30>" . (26760 32460)))
                 "Missing File"
                 '((0 . medium))
                 "/tmp/chime-this-path-does-not-exist-xyz.org"
                 42))
         (buffer-before (current-buffer)))
    (chime--jump-to-event event)
    (should (eq buffer-before (current-buffer)))))

(ert-deftest test-chime-jump-to-event-boundary-uses-org-show-entry-fallback ()
  "Boundary: when `org-fold-show-entry' is unbound, falls back to `org-show-entry'."
  (unwind-protect
      (let* ((content "* Heading
body
")
             (file (test-chime-jump-to-event--make-temp-org-file content))
             (event (chime--make-event
                     '(("<2026-05-10 Sun 09:30>" . (26760 32460)))
                     "Heading"
                     '((0 . medium))
                     file
                     1))
             (fallback-called nil)
             (orig-fboundp (symbol-function 'fboundp))
             (buffer-before-jump (current-buffer)))
        (unwind-protect
            (cl-letf (((symbol-function 'fboundp)
                       (lambda (sym)
                         (and (not (eq sym 'org-fold-show-entry))
                              (funcall orig-fboundp sym))))
                      ((symbol-function 'org-show-entry)
                       (lambda () (setq fallback-called t))))
              (chime--jump-to-event event)
              (should fallback-called)
              (should (string= file (buffer-file-name))))
          (when (get-file-buffer file)
            (kill-buffer (get-file-buffer file)))
          (when (buffer-live-p buffer-before-jump)
            (switch-to-buffer buffer-before-jump))))
    (chime-delete-test-base-dir)))

(provide 'test-chime-jump-to-event)
;;; test-chime-jump-to-event.el ends here
