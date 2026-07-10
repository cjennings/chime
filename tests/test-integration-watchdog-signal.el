;;; test-integration-watchdog-signal.el --- Real-signal watchdog tests -*- lexical-binding: t; -*-

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

;; Integration tests for the watchdog against a genuinely stuck child.
;;
;; The unit suite (test-chime-async-watchdog.el, test-chime-async-lifecycle.el)
;; stubs the whole process layer, so the signal semantics the watchdog rests
;; on were unverified anywhere.  These tests spawn real processes and let the
;; real kernel deliver the real signals.
;;
;; Components integrated:
;; - chime--kill-async-process (real)
;; - chime--interrupt-stale-process (real)
;; - Emacs process primitives: start-process, delete-process, process-live-p (real)
;; - chime--record-async-failure (MOCKED — the failure machinery has its own tests)
;;
;; Validates:
;; - A child that ignores SIGINT is still killed
;; - The child's process buffer is reaped, which async.el would leak
;; - The watchdog abandons the stuck child and lets the next tick spawn
;;
;; Tagged :slow: each test spawns processes and waits on the kernel.  Run
;; with `make test-all'.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Helpers

(defun test-chime-signal--spawn-sigint-immune-child ()
  "Spawn a real child that traps SIGINT and refuses to die from it.
This is the shape of the bug: a batch Emacs blocked on an interactive
prompt ignores the interrupt and lives on as a zombie."
  (let ((process (start-process
                  "chime-sigint-immune" (generate-new-buffer " *chime-sig*")
                  "sh" "-c" "trap '' INT; sleep 60")))
    (set-process-query-on-exit-flag process nil)
    ;; Give the shell a moment to install the trap.
    (sleep-for 0.3)
    process))

(defun test-chime-signal--wait-for-death (process seconds)
  "Wait up to SECONDS for PROCESS to die.  Return non-nil if it did."
  (let ((deadline (time-add (current-time) (seconds-to-time seconds))))
    (while (and (process-live-p process)
                (time-less-p (current-time) deadline))
      (accept-process-output process 0 50))
    (not (process-live-p process))))

;;; Integration: the kill path against a real signal-immune child

(ert-deftest test-integration-watchdog-sigint-immune-child-is-still-killed ()
  "A child that traps SIGINT survives an interrupt but not `chime--kill-async-process'.
This is the whole reason the watchdog escalates: `interrupt-process' is a
request, and a stuck child is entitled to ignore it."
  :tags '(:slow)
  (let ((process (test-chime-signal--spawn-sigint-immune-child)))
    (unwind-protect
        (progn
          (should (process-live-p process))
          ;; SIGINT: politely ignored.
          (interrupt-process process)
          (should-not (test-chime-signal--wait-for-death process 1.5))
          (should (process-live-p process))
          ;; The kill path does not ask.
          (chime--kill-async-process process)
          (should-not (process-live-p process)))
      (when (process-live-p process) (delete-process process)))))

(ert-deftest test-integration-watchdog-killed-child-leaves-no-buffer ()
  "The killed child's process buffer is reaped rather than leaked.
async.el kills a child's buffer only on a zero exit, so every signalled
child would otherwise leak one, once per `chime-async-timeout' for as long
as the hang persists."
  :tags '(:slow)
  (let* ((process (test-chime-signal--spawn-sigint-immune-child))
         (buffer (process-buffer process)))
    (unwind-protect
        (progn
          (should (buffer-live-p buffer))
          (chime--kill-async-process process)
          (should-not (process-live-p process))
          (should-not (buffer-live-p buffer)))
      (when (process-live-p process) (delete-process process))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest test-integration-watchdog-abandons-a-real-stuck-child ()
  "The watchdog kills a real over-age child, records the failure, and clears state.
Only `chime--record-async-failure' is mocked; the process, the signal, and
the age check are all real."
  :tags '(:slow)
  (let* ((process (test-chime-signal--spawn-sigint-immune-child))
         (recorded nil)
         (chime-async-timeout 1)
         (chime--process process)
         (chime--process-generation 0)
         ;; Backdate the spawn so the child is over-age immediately.
         (chime--process-start-time (time-subtract (current-time)
                                                   (seconds-to-time 30))))
    (unwind-protect
        (progn
          (cl-letf (((symbol-function 'chime--record-async-failure)
                     (lambda (err prefix) (setq recorded (cons prefix err)))))
            (chime--interrupt-stale-process))
          (should-not (process-live-p process))
          (should-not chime--process)
          (should-not chime--process-start-time)
          ;; The straggler's callback is orphaned.
          (should (= chime--process-generation 1))
          (should (equal "Async watchdog" (car recorded))))
      (when (process-live-p process) (delete-process process)))))

(ert-deftest test-integration-watchdog-leaves-a-young-real-child-alone ()
  "A child inside its timeout is not killed, even though it is real and stuck."
  :tags '(:slow)
  (let* ((process (test-chime-signal--spawn-sigint-immune-child))
         (chime-async-timeout 60)
         (chime--process process)
         (chime--process-generation 0)
         (chime--process-start-time (current-time)))
    (unwind-protect
        (progn
          (chime--interrupt-stale-process)
          (should (process-live-p process))
          (should (eq chime--process process))
          (should (= chime--process-generation 0)))
      (when (process-live-p process) (delete-process process))
      (let ((buffer (process-buffer process)))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(provide 'test-integration-watchdog-signal)
;;; test-integration-watchdog-signal.el ends here
