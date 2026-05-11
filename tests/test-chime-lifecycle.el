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

(ert-deftest test-chime-stop-interrupts-running-process ()
  "Normal: when chime--process is set, `chime--stop' interrupts it and clears the var."
  (let ((interrupted nil)
        (chime--timer nil)
        (chime--process 'fake-process)
        (chime--validation-done t)
        (chime--validation-retry-count 5))
    (cl-letf (((symbol-function 'interrupt-process)
               (lambda (proc) (setq interrupted proc))))
      (chime--stop))
    (should (eq 'fake-process interrupted))
    (should (null chime--process))
    (should-not chime--validation-done)
    (should (= 0 chime--validation-retry-count))))

(ert-deftest test-chime-stop-no-process-skips-interrupt ()
  "Boundary: with chime--process nil, `interrupt-process' is never called."
  (let ((interrupted nil)
        (chime--timer nil)
        (chime--process nil)
        (chime--validation-done t)
        (chime--validation-retry-count 5))
    (cl-letf (((symbol-function 'interrupt-process)
               (lambda (proc) (setq interrupted proc))))
      (chime--stop))
    (should (null interrupted))
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
