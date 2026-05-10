;;; test-chime-refresh-modeline.el --- Tests for manual modeline refresh -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Tests for `chime-refresh-modeline'.  Manual refresh should share the
;; startup validation gate used by `chime-check', but it must remain a
;; modeline-only operation and never send notifications.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

(defmacro test-chime-refresh-modeline--with-validation-state (&rest body)
  "Run BODY with isolated chime validation state."
  (declare (indent 0) (debug t))
  `(let ((original-validation-done chime--validation-done)
         (original-validation-retry-count chime--validation-retry-count)
         (original-validation-max-retries chime--validation-max-retries)
         (original-org-agenda-files org-agenda-files))
     (unwind-protect
         (progn
           (setq chime--validation-done nil)
           (setq chime--validation-retry-count 0)
           (setq chime--validation-max-retries 3)
           ,@body)
       (setq chime--validation-done original-validation-done)
       (setq chime--validation-retry-count original-validation-retry-count)
       (setq chime--validation-max-retries original-validation-max-retries)
       (setq org-agenda-files original-org-agenda-files))))

(ert-deftest test-chime-refresh-modeline-nil-agenda-files-skips-fetch ()
  "Error: nil `org-agenda-files' should validate and skip fetch."
  (test-chime-refresh-modeline--with-validation-state
    (setq org-agenda-files nil)
    (let ((fetch-called nil)
          (messages nil))
      (cl-letf (((symbol-function 'chime--fetch-and-process)
                 (lambda (_callback)
                   (setq fetch-called t)))
                ((symbol-function 'message)
                 (lambda (format-string &rest args)
                   (push (apply #'format format-string args) messages))))
        (chime-refresh-modeline)
        (should-not fetch-called)
        (should (= 1 chime--validation-retry-count))
        (should (cl-some (lambda (msg)
                          (string-match-p "Waiting for org-agenda-files" msg))
                        messages))))))

(ert-deftest test-chime-refresh-modeline-empty-agenda-files-skips-fetch ()
  "Error: empty `org-agenda-files' should validate and skip fetch."
  (test-chime-refresh-modeline--with-validation-state
    (setq org-agenda-files '())
    (let ((fetch-called nil))
      (cl-letf (((symbol-function 'chime--fetch-and-process)
                 (lambda (_callback)
                   (setq fetch-called t)))
                ((symbol-function 'message)
                 (lambda (&rest _args) nil)))
        (chime-refresh-modeline)
        (should-not fetch-called)
        (should (= 1 chime--validation-retry-count))
        (should-not chime--validation-done)))))

(ert-deftest test-chime-refresh-modeline-valid-agenda-files-fetches-events ()
  "Normal: valid configuration should fetch and update the modeline."
  (test-chime-refresh-modeline--with-validation-state
    (setq org-agenda-files '("/tmp/chime-refresh-test.org"))
    (let ((update-called nil)
          (notifications-called nil)
          (events '(((title . "Meeting")
                     (times . nil)
                     (intervals . nil)))))
      (cl-letf (((symbol-function 'chime--fetch-and-process)
                 (lambda (callback)
                   (funcall callback events)))
                ((symbol-function 'chime--update-modeline)
                 (lambda (received-events)
                   (setq update-called received-events)))
                ((symbol-function 'chime--process-notifications)
                 (lambda (_events)
                   (setq notifications-called t))))
        (chime-refresh-modeline)
        (should (eq update-called events))
        (should-not notifications-called)
        (should chime--validation-done)
        (should (= 0 chime--validation-retry-count))))))

(provide 'test-chime-refresh-modeline)
;;; test-chime-refresh-modeline.el ends here
