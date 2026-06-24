;;; test-testutil-general.el --- Tests for shared test file utilities -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Tests for the shared filesystem helpers in testutil-general.el.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

(ert-deftest test-chime-test-default-base-dir-uses-env-override ()
  "Normal: CHIME_TEST_TMPDIR selects an explicit test root."
  (cl-letf (((symbol-function 'getenv)
             (lambda (name)
               (when (string= name "CHIME_TEST_TMPDIR")
                 "/tmp/chime-explicit-root"))))
    (should (equal "/tmp/chime-explicit-root/"
                   (chime-test--default-base-dir)))))

(ert-deftest test-chime-test-default-base-dir-uses-temporary-directory ()
  "Normal: absent override uses a unique temp-directory path."
  (let ((temporary-file-directory "/tmp/chime-parent/"))
    (cl-letf (((symbol-function 'getenv) (lambda (_name) nil)))
      (should (string-prefix-p
               "/tmp/chime-parent/chime-tests-"
               (chime-test--default-base-dir))))))

(ert-deftest test-chime-test-base-dir-is-not-fixed-home-path ()
  "Regression: default test root is no longer ~/.temp-chime-tests/."
  (skip-unless (not (getenv "CHIME_TEST_TMPDIR")))
  (should-not
   (equal (expand-file-name "~/.temp-chime-tests/")
          chime-test-base-dir)))

(ert-deftest test-chime-test-base-dir-create-and-delete-roundtrip ()
  "Normal: create and delete work for the configured test root."
  (unwind-protect
      (progn
        (should (equal (file-name-as-directory chime-test-base-dir)
                       (chime-create-test-base-dir)))
        (should (file-directory-p chime-test-base-dir)))
    (chime-delete-test-base-dir))
  (should-not (file-exists-p chime-test-base-dir)))

(provide 'test-testutil-general)
;;; test-testutil-general.el ends here
