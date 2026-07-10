;;; test-chime-lifecycle.el --- Tests for chime--stop and chime--start -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;; Author: Craig Jennings <c@cjennings.net>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Unit tests for the internal lifecycle entry points `chime--stop' and
;; `chime--start'.  Tests cover branches not exercised by higher-level
;; mode-toggle tests: in-progress process cleanup and the debug-only
;; scheduling log line.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'cl-lib)

(ert-deftest test-chime-stop-kills-running-process ()
  "Normal: when chime--process is set, `chime--stop' kills it and clears the var.
The child is killed rather than interrupted, because SIGINT is a request a
child stuck in a blocking read can ignore."
  (let ((killed nil)
        (chime--timer nil)
        (chime--process 'fake-process)
        (chime--process-generation 0)
        (chime--validation-done t)
        (chime--validation-retry-count 5))
    (cl-letf (((symbol-function 'chime--kill-async-process)
               (lambda (proc) (setq killed proc))))
      (chime--stop))
    (should (eq 'fake-process killed))
    (should (null chime--process))
    ;; The abandoned child's callback is orphaned.
    (should (= 1 chime--process-generation))
    (should-not chime--validation-done)
    (should (= 0 chime--validation-retry-count))))

(ert-deftest test-chime-stop-no-process-kills-nothing ()
  "Boundary: with chime--process nil, no process is killed."
  (let ((killed 'untouched)
        (chime--timer nil)
        (chime--process nil)
        (chime--process-generation 0)
        (chime--validation-done t)
        (chime--validation-retry-count 5))
    (cl-letf (((symbol-function 'chime--kill-async-process)
               (lambda (proc) (setq killed proc))))
      (chime--stop))
    ;; chime--stop calls the helper unconditionally; it must tolerate nil.
    (should (null killed))
    (should-not chime--validation-done)
    (should (= 0 chime--validation-retry-count))))

(ert-deftest test-chime-start-logs-debug-message-when-feature-loaded ()
  "Normal: with the chime-debug feature loaded, start emits a scheduling log line."
  (let ((logged nil)
        (chime--timer nil)
        (chime--process nil))
    (cl-letf (((symbol-function 'featurep)
               (lambda (feat &rest _) (eq feat 'chime-debug)))
              ((symbol-function 'run-at-time)
               (lambda (&rest _) 'fake-timer))
              ((symbol-function 'chime--log-silently)
               (lambda (fmt &rest args)
                 (push (apply #'format fmt args) logged))))
      (chime--start))
    (should (cl-some (lambda (m) (string-match-p "Scheduling first check" m))
                     logged))
    (should (eq 'fake-timer chime--timer))))

(ert-deftest test-chime-start-skips-debug-log-when-feature-absent ()
  "Boundary: without the chime-debug feature loaded, no log line is emitted."
  (let ((logged nil)
        (chime--timer nil)
        (chime--process nil))
    (cl-letf (((symbol-function 'featurep)
               (lambda (feat &rest _) (not (eq feat 'chime-debug))))
              ((symbol-function 'run-at-time)
               (lambda (&rest _) 'fake-timer))
              ((symbol-function 'chime--log-silently)
               (lambda (fmt &rest args)
                 (push (apply #'format fmt args) logged))))
      (chime--start))
    (should (null logged))
    (should (eq 'fake-timer chime--timer))))

(provide 'test-chime-lifecycle)
;;; test-chime-lifecycle.el ends here
