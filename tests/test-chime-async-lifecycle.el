;;; test-chime-async-lifecycle.el --- Tests for async process lifecycle -*- lexical-binding: t; -*-

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

;; Unit tests for the async child's lifecycle: the spawn-generation guard
;; that discards a late callback, and the kill path that reaps a child the
;; watchdog abandoned.
;;
;; Two failure modes motivate these.
;;
;; A watchdog interrupt races a child that finishes just past the timeout.
;; The late callback nils `chime--process' -- which by then holds the
;; *replacement* child -- so the overlap guard breaks and a third child can
;; spawn.  It also resets the failure counter the watchdog just incremented.
;;
;; `interrupt-process' only asks.  A child stuck in a blocking read ignores
;; SIGINT and lives on as a zombie, invisible because `chime--process' was
;; already nil'd.  And async.el only kills a child's process buffer on a
;; zero exit, so every signalled child leaks its buffer.  A persistent hang
;; leaks one per `chime-async-timeout' until Emacs restarts.
;;
;; Tests cover normal cases, boundary cases, and error cases.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Helpers

(defun test-chime-lifecycle--reset ()
  "Reset the async state these tests touch."
  (setq chime--process nil)
  (setq chime--process-start-time nil)
  (setq chime--process-generation 0)
  (setq chime--consecutive-async-failures 0))

(defun test-chime-lifecycle--sleeper ()
  "Spawn a real, long-running child with a process buffer."
  (let ((process (start-process "chime-lifecycle-test"
                                (generate-new-buffer " *chime-test*")
                                "sleep" "60")))
    (set-process-query-on-exit-flag process nil)
    process))

;;; Normal Cases

(chime-deftest test-chime-lifecycle-fresh-result-is-processed ()
  "A result from the current generation is processed."
  (test-chime-lifecycle--reset)
  (let ((handled nil))
    (setq chime--process-generation 3)
    (cl-letf (((symbol-function 'chime--handle-async-success)
               (lambda (_callback events) (setq handled events))))
      (chime--handle-async-result 3 #'ignore '(:an-event))
      (should (equal handled '(:an-event))))))

(chime-deftest test-chime-lifecycle-fresh-result-clears-process-state ()
  "Processing a fresh result clears the process handle and its start time."
  (test-chime-lifecycle--reset)
  (setq chime--process 'a-process)
  (setq chime--process-start-time '(1 2))
  (cl-letf (((symbol-function 'chime--handle-async-success) (lambda (&rest _) nil)))
    (chime--handle-async-result 0 #'ignore '())
    (should-not chime--process)
    (should-not chime--process-start-time)))

;;; Boundary Cases

(chime-deftest test-chime-lifecycle-stale-result-is-discarded ()
  "A result from a superseded generation is ignored entirely."
  (test-chime-lifecycle--reset)
  (let ((handled nil)
        (failed nil))
    ;; Generation 1 was abandoned; generation 2 is the live child.
    (setq chime--process-generation 2)
    (setq chime--process 'the-replacement-child)
    (setq chime--consecutive-async-failures 1)
    (cl-letf (((symbol-function 'chime--handle-async-success)
               (lambda (&rest _) (setq handled t)))
              ((symbol-function 'chime--record-async-failure)
               (lambda (&rest _) (setq failed t))))
      (chime--handle-async-result 1 #'ignore '(:late-events))
      (should-not handled)
      (should-not failed)
      ;; The replacement child's handle survives.
      (should (eq chime--process 'the-replacement-child))
      ;; The watchdog's failure count is not reset by the straggler.
      (should (= chime--consecutive-async-failures 1)))))

(chime-deftest test-chime-lifecycle-stale-error-result-is-discarded ()
  "A late error sexp from a superseded child is ignored too."
  (test-chime-lifecycle--reset)
  (let ((failed nil))
    (setq chime--process-generation 5)
    (cl-letf (((symbol-function 'chime--record-async-failure)
               (lambda (&rest _) (setq failed t))))
      (chime--handle-async-result 4 #'ignore '(async-signal error "boom"))
      (should-not failed))))

(chime-deftest test-chime-lifecycle-watchdog-supersedes-the-generation ()
  "Interrupting a stale child bumps the generation, orphaning its callback."
  (test-chime-lifecycle--reset)
  (let ((now (current-time))
        (chime-async-timeout 10))
    (setq chime--process 'stuck-child)
    (setq chime--process-start-time (time-subtract now (seconds-to-time 60)))
    (setq chime--process-generation 7)
    (cl-letf (((symbol-function 'process-live-p) (lambda (_p) t))
              ((symbol-function 'chime--kill-async-process) (lambda (_p) nil))
              ((symbol-function 'chime--record-async-failure) (lambda (&rest _) nil)))
      (chime--interrupt-stale-process)
      (should (= chime--process-generation 8))
      (should-not chime--process)
      (should-not chime--process-start-time))))

(chime-deftest test-chime-lifecycle-stop-supersedes-the-generation ()
  "`chime--stop' orphans an in-flight callback and clears the counters."
  (test-chime-lifecycle--reset)
  (setq chime--process 'a-child)
  (setq chime--process-start-time '(1 2))
  (setq chime--process-generation 2)
  (setq chime--consecutive-async-failures 4)
  (cl-letf (((symbol-function 'chime--kill-async-process) (lambda (_p) nil)))
    (chime--stop)
    (should (= chime--process-generation 3))
    (should-not chime--process)
    (should-not chime--process-start-time)
    ;; A restart must not resume with the old failure count.
    (should (= chime--consecutive-async-failures 0))))

;;; Error Cases

(chime-deftest test-chime-lifecycle-kill-async-process-kills-child-and-buffer ()
  "`chime--kill-async-process' leaves neither a live child nor its buffer.
`interrupt-process' only asks; async.el only reaps the buffer on a zero exit."
  (let* ((process (test-chime-lifecycle--sleeper))
         (buffer (process-buffer process)))
    (should (process-live-p process))
    (should (buffer-live-p buffer))
    (chime--kill-async-process process)
    (should-not (process-live-p process))
    (should-not (buffer-live-p buffer))))

(chime-deftest test-chime-lifecycle-kill-async-process-tolerates-a-dead-child ()
  "Killing an already-dead process is a no-op, not an error."
  (let ((process (test-chime-lifecycle--sleeper)))
    (chime--kill-async-process process)
    (should-not (condition-case nil
                    (progn (chime--kill-async-process process) nil)
                  (error t)))))

(chime-deftest test-chime-lifecycle-kill-async-process-tolerates-nil ()
  "Killing nil is a no-op.  `chime--stop' calls it unconditionally."
  (should-not (condition-case nil
                  (progn (chime--kill-async-process nil) nil)
                (error t))))

(chime-deftest test-chime-lifecycle-kill-async-process-silences-the-sentinel ()
  "The killed child's sentinel does not run, so async.el can't act on it."
  (let ((process (test-chime-lifecycle--sleeper))
        (sentinel-ran nil))
    (set-process-sentinel process (lambda (&rest _) (setq sentinel-ran t)))
    (chime--kill-async-process process)
    (should-not sentinel-ran)))

(provide 'test-chime-async-lifecycle)
;;; test-chime-async-lifecycle.el ends here
