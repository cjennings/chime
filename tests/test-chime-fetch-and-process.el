;;; test-chime-fetch-and-process.el --- Tests for chime--fetch-and-process branches -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;; Author: Craig Jennings <c@cjennings.net>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Cover the two error branches inside the `chime--fetch-and-process'
;; async callback:
;;
;;   1. The async subprocess returned an `(async-signal . ERR)' tuple.
;;   2. The user-supplied callback raised an error during processing.
;;
;; Both are caught by the surrounding `condition-case' and routed through
;; `chime--record-async-failure' with a distinct prefix.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'cl-lib)

(ert-deftest test-chime-fetch-and-process-async-signal-records-failure ()
  "Error: when async returns an `async-signal' tuple, failure is recorded with the async prefix."
  (let ((recorded nil)
        (chime--process nil)
        (chime--last-check-time '(0 0))
        (chime-modeline-no-events-text " ⏰")
        (chime-modeline-string nil)
        (chime--consecutive-async-failures 0)
        (chime-max-consecutive-failures 0))
    (cl-letf (((symbol-function 'async-start)
               (lambda (_start-form finish-func)
                 (funcall finish-func '(async-signal error "boom"))
                 'fake-process))
              ((symbol-function 'chime--record-async-failure)
               (lambda (err prefix) (setq recorded (cons prefix err))))
              ((symbol-function 'force-mode-line-update) (lambda (&optional _))))
      (chime--fetch-and-process (lambda (_events) nil)))
    (should (equal "Async error" (car recorded)))
    (should (equal '(error "boom") (cdr recorded)))))

(ert-deftest test-chime-fetch-and-process-callback-error-records-failure ()
  "Error: when the callback raises during processing, failure is recorded with the processing prefix."
  (let ((recorded nil)
        (chime--process nil)
        (chime--last-check-time '(0 0))
        (chime-modeline-no-events-text " ⏰")
        (chime-modeline-string nil)
        (chime--consecutive-async-failures 0)
        (chime-max-consecutive-failures 0))
    (cl-letf (((symbol-function 'async-start)
               (lambda (_start-form finish-func)
                 (funcall finish-func '(((title . "Event"))))
                 'fake-process))
              ((symbol-function 'chime--record-async-failure)
               (lambda (err prefix) (setq recorded (cons prefix err))))
              ((symbol-function 'force-mode-line-update) (lambda (&optional _))))
      (chime--fetch-and-process (lambda (_events) (error "callback boom"))))
    (should (equal "Error processing events" (car recorded)))
    (should (string-match-p "callback boom"
                            (error-message-string (cdr recorded))))))

(ert-deftest test-chime-fetch-and-process-skips-when-process-live ()
  "Boundary: an active live process blocks a fresh fetch."
  (let ((fetched nil)
        (chime--process 'fake-live-process))
    (cl-letf (((symbol-function 'process-live-p)
               (lambda (proc) (eq proc 'fake-live-process)))
              ((symbol-function 'async-start)
               (lambda (&rest _)
                 (setq fetched t)
                 'unused)))
      (chime--fetch-and-process (lambda (_events) nil)))
    (should-not fetched)))

(provide 'test-chime-fetch-and-process)
;;; test-chime-fetch-and-process.el ends here
