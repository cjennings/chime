;;; test-chime-async-watchdog.el --- Tests for the async fetch watchdog -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;; Author: Craig Jennings <c@cjennings.net>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; A hung async child froze the modeline for 15+ hours: org-agenda-list hit
;; org's interactive "Non-existent agenda file ... [R]emove or [A]bort?"
;; prompt inside the -batch child, which blocked forever, and the overlap
;; guard in `chime--fetch-and-process' turned every subsequent tick into a
;; silent no-op.  A child that never returns is invisible to every failure
;; path — `chime--consecutive-async-failures' stays 0.
;;
;; Two layers under test here:
;;
;;   1. The child payload from `chime--retrieve-events' must set
;;      `org-agenda-skip-unavailable-files' so a vanished agenda file is
;;      skipped instead of prompting.  Any prompt in a -batch child is a
;;      permanent hang.
;;
;;   2. The watchdog: a live child older than `chime-async-timeout' is
;;      interrupted, recorded through `chime--record-async-failure', and
;;      replaced by a fresh spawn in the same tick.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'cl-lib)

;;;; Layer 1 — prompt-proof child payload

(ert-deftest test-chime-retrieve-events-payload-skips-unavailable-files ()
  "Normal: the child payload disables org's missing-agenda-file prompt.
`org-agenda-skip-unavailable-files' must be set to t in the child form so
`org-agenda-list' skips a vanished file with a message instead of blocking
forever on an interactive prompt no one can answer."
  (let ((form (chime--retrieve-events)))
    (should (member '(setf org-agenda-skip-unavailable-files t) form))))

;;;; Layer 2 — watchdog on the overlap guard

(ert-deftest test-chime-fetch-and-process-young-child-blocks-tick ()
  "Normal: a live child younger than the timeout blocks the tick untouched."
  (let* ((now (current-time))
         (interrupted nil)
         (spawned nil)
         (chime--process 'fake-live-process)
         (chime--process-start-time (time-subtract now (seconds-to-time 10)))
         (chime-async-timeout 120))
    (cl-letf (((symbol-function 'current-time) (lambda () now))
              ((symbol-function 'process-live-p)
               (lambda (proc) (eq proc 'fake-live-process)))
              ((symbol-function 'interrupt-process)
               (lambda (proc) (setq interrupted proc)))
              ((symbol-function 'async-start)
               (lambda (&rest _) (setq spawned t) 'unused)))
      (chime--fetch-and-process (lambda (_events) nil)))
    (should-not interrupted)
    (should-not spawned)
    (should (eq 'fake-live-process chime--process))))

(ert-deftest test-chime-fetch-and-process-child-at-threshold-not-interrupted ()
  "Boundary: a child exactly at `chime-async-timeout' seconds is left alone.
Interruption requires strictly exceeding the timeout."
  (let* ((now (current-time))
         (interrupted nil)
         (spawned nil)
         (chime--process 'fake-live-process)
         (chime--process-start-time (time-subtract now (seconds-to-time 120)))
         (chime-async-timeout 120))
    (cl-letf (((symbol-function 'current-time) (lambda () now))
              ((symbol-function 'process-live-p)
               (lambda (proc) (eq proc 'fake-live-process)))
              ((symbol-function 'interrupt-process)
               (lambda (proc) (setq interrupted proc)))
              ((symbol-function 'async-start)
               (lambda (&rest _) (setq spawned t) 'unused)))
      (chime--fetch-and-process (lambda (_events) nil)))
    (should-not interrupted)
    (should-not spawned)))

(ert-deftest test-chime-fetch-and-process-stale-child-interrupted-and-respawned ()
  "Error: an over-age child is interrupted, recorded as a failure, replaced.
The hung child must feed the existing consecutive-failures machinery (via
`chime--record-async-failure') instead of silently blocking every tick, and
the same tick spawns a fresh child."
  (let* ((now (current-time))
         (interrupted nil)
         (recorded nil)
         (spawned nil)
         (chime--process 'fake-live-process)
         (chime--process-start-time (time-subtract now (seconds-to-time 121)))
         (chime-async-timeout 120))
    (cl-letf (((symbol-function 'current-time) (lambda () now))
              ((symbol-function 'process-live-p)
               (lambda (proc) (eq proc 'fake-live-process)))
              ((symbol-function 'interrupt-process)
               (lambda (proc) (setq interrupted proc)))
              ((symbol-function 'chime--record-async-failure)
               (lambda (err prefix) (setq recorded (cons prefix err))))
              ((symbol-function 'async-start)
               (lambda (&rest _) (setq spawned t) 'new-fake-process)))
      (chime--fetch-and-process (lambda (_events) nil)))
    (should (eq 'fake-live-process interrupted))
    (should (equal "Async watchdog" (car recorded)))
    (should (string-match-p "chime-async-timeout"
                            (error-message-string (cdr recorded))))
    (should spawned)
    (should (eq 'new-fake-process chime--process))))

(ert-deftest test-chime-fetch-and-process-nil-timeout-disables-watchdog ()
  "Boundary: `chime-async-timeout' nil disables the watchdog entirely.
Even an ancient live child is left alone and still blocks the tick."
  (let* ((now (current-time))
         (interrupted nil)
         (spawned nil)
         (chime--process 'fake-live-process)
         (chime--process-start-time (time-subtract now (seconds-to-time 99999)))
         (chime-async-timeout nil))
    (cl-letf (((symbol-function 'current-time) (lambda () now))
              ((symbol-function 'process-live-p)
               (lambda (proc) (eq proc 'fake-live-process)))
              ((symbol-function 'interrupt-process)
               (lambda (proc) (setq interrupted proc)))
              ((symbol-function 'async-start)
               (lambda (&rest _) (setq spawned t) 'unused)))
      (chime--fetch-and-process (lambda (_events) nil)))
    (should-not interrupted)
    (should-not spawned)
    (should (eq 'fake-live-process chime--process))))

(ert-deftest test-chime-fetch-and-process-spawn-records-start-time ()
  "Normal: a fresh spawn records the spawn timestamp for the watchdog."
  (let* ((now (current-time))
         (chime--process nil)
         (chime--process-start-time nil)
         (chime-async-timeout 120))
    (cl-letf (((symbol-function 'current-time) (lambda () now))
              ((symbol-function 'async-start)
               (lambda (&rest _) 'fake-process)))
      (chime--fetch-and-process (lambda (_events) nil)))
    (should (eq 'fake-process chime--process))
    (should (equal now chime--process-start-time))))

(provide 'test-chime-async-watchdog)
;;; test-chime-async-watchdog.el ends here
