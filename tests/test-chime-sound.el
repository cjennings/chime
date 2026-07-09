;;; test-chime-sound.el --- Tests for chime's sound playback -*- lexical-binding: t; -*-

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

;; Unit tests for `chime--play-sound', `chime--find-sound-player' and
;; `chime--play-sound-external'.
;;
;; Emacs' built-in `play-sound-file' talks to ALSA directly and dies with
;; "No usable sound device driver found" on any system whose ALSA `default'
;; PCM doesn't resolve -- which is every PipeWire box that never got
;; `pcm.!default' pointed at the sound server.  It is also synchronous.
;; So chime prefers an external player and keeps `play-sound-file' as the
;; fallback.  These tests pin that contract.
;;
;; `play-sound-file' is the system boundary here and is always mocked, so
;; no test opens an audio device.  Where a test needs a real process --
;; asynchrony and the exit-status sentinel cannot be observed through a
;; mock -- it spawns `true' or `false' as a stand-in player.  No real audio
;; player is ever run.
;;
;; Tests cover normal cases, boundary cases, and error cases.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Helpers

(defconst test-chime-sound--real-start-process
  (symbol-function 'start-process)
  "The real `start-process', captured so mocks can still spawn a stand-in.
Mocking `set-process-query-on-exit-flag' would need a native-comp
trampoline, so tests hand the production code a real process instead.")

(defun test-chime-sound--existing-file ()
  "Return the path of a real file inside the test base dir."
  (let ((file (expand-file-name "chime-test.wav" chime-test-base-dir)))
    (with-temp-file file (insert "not really a wav"))
    file))

(defun test-chime-sound--stand-in-process ()
  "Spawn a real, immediately-exiting process to stand in for a player."
  (funcall test-chime-sound--real-start-process "chime-sound-test" nil "true"))

;;; Normal Cases

(chime-deftest test-chime-sound-find-sound-player-auto-returns-first-available ()
  "Auto mode returns the only candidate found on PATH."
  (let ((chime-sound-player 'auto))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (cmd) (equal cmd "aplay"))))
      ;; The sound-server players are absent, so aplay is all that is left.
      (should (equal (chime--find-sound-player) "aplay")))))

(chime-deftest test-chime-sound-find-sound-player-prefers-sound-server-over-raw-alsa ()
  "Auto mode prefers a sound-server player over raw ALSA."
  (let ((chime-sound-player 'auto))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (cmd) (member cmd '("pw-play" "paplay" "aplay")))))
      (should (equal (chime--find-sound-player) "pw-play")))))

(chime-deftest test-chime-sound-find-sound-player-explicit-string-is-used ()
  "An explicit player string is used when it is on PATH."
  (let ((chime-sound-player "mpv"))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (cmd) (equal cmd "mpv"))))
      (should (equal (chime--find-sound-player) "mpv")))))

(chime-deftest test-chime-sound-find-sound-player-emacs-mode-returns-nil ()
  "Emacs mode never selects an external player."
  (let ((chime-sound-player 'emacs))
    (cl-letf (((symbol-function 'executable-find) (lambda (_cmd) t)))
      (should-not (chime--find-sound-player)))))

(chime-deftest test-chime-sound-play-sound-spawns-external-player ()
  "The external player is spawned with the sound file, and Emacs' player is not used."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player 'auto)
         (spawned nil)
         (emacs-player-called nil))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (cmd) (equal cmd "pw-play")))
              ((symbol-function 'start-process)
               (lambda (_name _buffer program &rest args)
                 (setq spawned (cons program args))
                 (test-chime-sound--stand-in-process)))
              ((symbol-function 'play-sound-file)
               (lambda (&rest _) (setq emacs-player-called t))))
      (chime--play-sound)
      (should (equal spawned (list "pw-play" file)))
      (should-not emacs-player-called))))

(chime-deftest test-chime-sound-play-sound-external-returns-a-process ()
  "External playback hands back a process rather than awaiting the clip.
Runs the real spawn path against `true', a harmless stand-in player.
Returning a process is the evidence that playback is asynchronous: the
synchronous `play-sound-file' path returns t instead."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player "true")
         (emacs-player-called nil))
    (cl-letf (((symbol-function 'play-sound-file)
               (lambda (&rest _) (setq emacs-player-called t))))
      (should (processp (chime--play-sound)))
      (should-not emacs-player-called))))

(chime-deftest test-chime-sound-play-sound-emacs-mode-passes-device ()
  "Emacs mode calls `play-sound-file' with `chime-sound-device' as DEVICE."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player 'emacs)
         (chime-sound-device "pipewire")
         (call-args nil))
    (cl-letf (((symbol-function 'play-sound-file)
               (lambda (&rest args) (setq call-args args))))
      (chime--play-sound)
      (should (equal call-args (list file nil "pipewire"))))))

;;; Boundary Cases

(chime-deftest test-chime-sound-play-sound-nil-device-passed-through ()
  "A nil `chime-sound-device' is still passed as the DEVICE argument."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player 'emacs)
         (chime-sound-device nil)
         (call-args nil))
    (cl-letf (((symbol-function 'play-sound-file)
               (lambda (&rest args) (setq call-args args))))
      (chime--play-sound)
      (should (equal call-args (list file nil nil))))))

(chime-deftest test-chime-sound-play-sound-nil-sound-file-plays-nothing ()
  "No sound file configured means nothing is played."
  (let ((chime-sound-file nil)
        (chime-sound-player 'auto)
        (played nil))
    (cl-letf (((symbol-function 'executable-find) (lambda (_cmd) t))
              ((symbol-function 'start-process)
               (lambda (&rest _) (setq played t) 'fake-process))
              ((symbol-function 'play-sound-file)
               (lambda (&rest _) (setq played t))))
      (chime--play-sound)
      (should-not played))))

(chime-deftest test-chime-sound-play-sound-missing-file-plays-nothing ()
  "A configured but absent sound file means nothing is played."
  (let ((chime-sound-file (expand-file-name "absent.wav" chime-test-base-dir))
        (chime-sound-player 'auto)
        (played nil))
    (cl-letf (((symbol-function 'executable-find) (lambda (_cmd) t))
              ((symbol-function 'start-process)
               (lambda (&rest _) (setq played t) 'fake-process))
              ((symbol-function 'play-sound-file)
               (lambda (&rest _) (setq played t))))
      (chime--play-sound)
      (should-not played))))

(chime-deftest test-chime-sound-play-sound-no-player-found-falls-back-to-emacs ()
  "With no external player on PATH, Emacs' `play-sound-file' is used."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player 'auto)
         (emacs-player-called nil))
    (cl-letf (((symbol-function 'executable-find) (lambda (_cmd) nil))
              ((symbol-function 'play-sound-file)
               (lambda (&rest _) (setq emacs-player-called t))))
      (chime--play-sound)
      (should emacs-player-called))))

(chime-deftest test-chime-sound-play-sound-explicit-player-absent-falls-back-to-emacs ()
  "An explicit player that is not installed falls back to Emacs' player."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player "no-such-player")
         (emacs-player-called nil))
    (cl-letf (((symbol-function 'executable-find) (lambda (_cmd) nil))
              ((symbol-function 'play-sound-file)
               (lambda (&rest _) (setq emacs-player-called t))))
      (chime--play-sound)
      (should emacs-player-called))))

;;; Error Cases

(chime-deftest test-chime-sound-external-spawn-failure-falls-back-to-emacs ()
  "When spawning the external player signals, Emacs' player is used instead."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player 'auto)
         (emacs-player-called nil))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (cmd) (equal cmd "pw-play")))
              ((symbol-function 'start-process)
               (lambda (&rest _) (error "Spawning failed")))
              ((symbol-function 'play-sound-file)
               (lambda (&rest _) (setq emacs-player-called t))))
      (chime--play-sound)
      (should emacs-player-called))))

(chime-deftest test-chime-sound-play-sound-external-returns-nil-on-spawn-error ()
  "`chime--play-sound-external' reports failure rather than signalling."
  (cl-letf (((symbol-function 'start-process)
             (lambda (&rest _) (error "Spawning failed"))))
    (should-not (chime--play-sound-external "pw-play" "/tmp/whatever.wav"))))

(chime-deftest test-chime-sound-external-nonzero-exit-is-reported ()
  "A player that spawns but fails is reported rather than failing silently.
`false' stands in for a player that cannot decode the file."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player "false")
         (messages nil))
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args) (push (apply #'format fmt args) messages))))
      (let ((process (chime--play-sound)))
        (should (processp process))
        ;; The sentinel fires when the player exits, not before.
        (while (process-live-p process)
          (accept-process-output process 0 50)))
      (should (= (length messages) 1))
      (should (string-match-p "Failed to play sound" (car messages)))
      (should (string-match-p "false" (car messages))))))

(chime-deftest test-chime-sound-external-zero-exit-is-silent ()
  "A player that succeeds reports nothing."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player "true")
         (messages nil))
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args) (push (apply #'format fmt args) messages))))
      (let ((process (chime--play-sound)))
        (while (process-live-p process)
          (accept-process-output process 0 50)))
      (should-not messages))))

(chime-deftest test-chime-sound-both-players-failing-reports-once-and-does-not-signal ()
  "When both players fail, the error is reported and not propagated."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player 'auto)
         (messages nil))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (cmd) (equal cmd "pw-play")))
              ((symbol-function 'start-process)
               (lambda (&rest _) (error "Spawning failed")))
              ((symbol-function 'play-sound-file)
               (lambda (&rest _) (error "No usable sound device driver found")))
              ((symbol-function 'message)
               (lambda (fmt &rest args) (push (apply #'format fmt args) messages))))
      ;; Must not signal.
      (should-not (condition-case nil
                      (progn (chime--play-sound) nil)
                    (error t)))
      (should (= (length messages) 1))
      (should (string-match-p "Failed to play sound" (car messages))))))

(chime-deftest test-chime-sound-emacs-player-error-is-reported-not-signalled ()
  "A `play-sound-file' failure is reported and swallowed."
  (let* ((file (test-chime-sound--existing-file))
         (chime-sound-file file)
         (chime-sound-player 'emacs)
         (messages nil))
    (cl-letf (((symbol-function 'play-sound-file)
               (lambda (&rest _) (error "No usable sound device driver found")))
              ((symbol-function 'message)
               (lambda (fmt &rest args) (push (apply #'format fmt args) messages))))
      (should-not (condition-case nil
                      (progn (chime--play-sound) nil)
                    (error t)))
      (should (= (length messages) 1))
      (should (string-match-p "Failed to play sound" (car messages))))))

(chime-deftest test-chime-sound-device-rejects-non-string-at-customize-time ()
  "Setting `chime-sound-device' to a non-string is rejected."
  (should-error (customize-set-variable 'chime-sound-device 42)
                :type 'user-error)
  ;; nil is allowed -- it means "let the system decide".
  (customize-set-variable 'chime-sound-device nil)
  (should-not chime-sound-device))

(provide 'test-chime-sound)
;;; test-chime-sound.el ends here
