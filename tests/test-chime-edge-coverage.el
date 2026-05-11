;;; test-chime-edge-coverage.el --- Cover edge branches surfaced by coverage gaps -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

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

;; Small focused tests that exercise specific branches missed by the
;; per-function suites.  Each test points at the line range it covers
;; so future readers can correlate quickly.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))
(require 'cl-lib)

;;;; chime--day-wide-notification-text fallback (chime.el ~ "t branch")

(ert-deftest test-chime-day-wide-notification-text-future-event-uses-today-fallback ()
  "Boundary: a future event reaches the cond's `t' fallback when no advance notice is configured."
  (let* ((future-time (test-time-tomorrow-at 10 0))
         (timestamp (test-timestamp-string future-time t))
         (event (chime--make-event (list (cons timestamp nil))
                                   "Future Event"
                                   '((0 . medium))))
         (chime-day-wide-advance-notice nil))
    (should (string= "Future Event is due or scheduled today"
                     (chime--day-wide-notification-text event)))))

;;;; chime--format-event-for-tooltip pcase fallback

(ert-deftest test-chime-format-event-for-tooltip-unknown-placeholder-passes-through ()
  "Boundary: unknown %X placeholders fall through the pcase and are kept as-is."
  (let* ((time (test-time-today-at 14 30))
         (timestamp (test-timestamp-string time))
         (chime-tooltip-event-format "%t %T %u %X %Z")
         (result (chime--format-event-for-tooltip timestamp 30 "Meeting")))
    (should (string-match-p "%X" result))
    (should (string-match-p "%Z" result))))

;;;; chime--build-upcoming-events-list show-all-day-p=nil branch

(ert-deftest test-chime-build-upcoming-events-list-filters-day-wide-when-not-shown ()
  "Normal: when SHOW-ALL-DAY-P is nil, the call routes through `chime--filter-day-wide-events'."
  (let* ((now (test-time-now))
         (timed-time (test-time-at 0 1 0))
         (timed-ts (test-timestamp-string timed-time))
         (all-day-ts (test-timestamp-string now t))
         (event (chime--make-event
                 (list (cons timed-ts timed-time)
                       (cons all-day-ts nil))
                 "Mixed Event"
                 '((0 . medium))))
         (lookahead 1440))
    (let ((with-all (chime--build-upcoming-events-list (list event) now lookahead t))
          (without-all (chime--build-upcoming-events-list (list event) now lookahead nil)))
      (should (= 1 (length with-all)))
      (should (= 1 (length without-all)))
      ;; Both pick the timed entry as soonest; the branch coverage is the
      ;; point of this test.
      (should (equal (nth 1 (car with-all))
                     (nth 1 (car without-all)))))))

;;;; chime--timestamp-parse error path without context arg

(ert-deftest test-chime-timestamp-parse-error-without-context-omits-context-suffix ()
  "Error: when CONTEXT is nil, the failure message omits the in '...' suffix."
  (let ((captured nil))
    (cl-letf (((symbol-function 'org-parse-time-string)
               (lambda (&rest _) (error "synthetic parse failure")))
              ((symbol-function 'message)
               (lambda (fmt &rest args)
                 (push (apply #'format fmt args) captured))))
      (should (null (chime--timestamp-parse "<2026-05-11 Mon 09:30>"))))
    (let ((joined (mapconcat #'identity captured "\n")))
      (should (string-match-p "Failed to parse timestamp" joined))
      ;; No "in '...': " suffix when context is nil.
      (should-not (string-match-p " in '" joined)))))

(ert-deftest test-chime-timestamp-parse-error-with-context-includes-context-suffix ()
  "Error: when CONTEXT is non-nil, the failure message includes the in '...' suffix."
  (let ((captured nil))
    (cl-letf (((symbol-function 'org-parse-time-string)
               (lambda (&rest _) (error "synthetic parse failure")))
              ((symbol-function 'message)
               (lambda (fmt &rest args)
                 (push (apply #'format fmt args) captured))))
      (should (null (chime--timestamp-parse "<2026-05-11 Mon 09:30>"
                                            "ContextEvent"))))
    (let ((joined (mapconcat #'identity captured "\n")))
      (should (string-match-p "in 'ContextEvent'" joined)))))

;;;; chime--extract-gcal-timestamps drawer without :END:

(ert-deftest test-chime-extract-gcal-timestamps-drawer-without-end-returns-empty ()
  "Boundary: drawer without a closing :END: yields no timestamps and does not error.
Exercises the `(point)' fallback branch in the drawer-end computation."
  (let* ((future (test-time-tomorrow-at 9 30))
         (ts (test-timestamp-string future))
         (content (format "* Meeting
:org-gcal:
%s
" ts)))
    (with-temp-buffer
      (org-mode)
      (insert content)
      (goto-char (point-min))
      (should (null (chime--extract-gcal-timestamps "Meeting"))))))

;;;; chime--display-validation-results :error branch

(ert-deftest test-chime-display-validation-results-counts-error-results ()
  "Normal: results with :error severity get counted into the summary."
  (let ((messages nil)
        (chime-validation-summary-format "errs=%d%s warns=%d%s"))
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args)
                 (push (apply #'format fmt args) messages))))
      (chime--display-validation-results
       '((:error "first failed" "first detail")
         (:error "second failed" "second detail")
         (:warning "third soft"  "third detail")
         (:ok      "fourth ok"   nil))))
    (should (member "errs=2s warns=1" (nreverse messages)))))

;;;; chime--record-async-failure with chime-debug feature loaded

(ert-deftest test-chime-record-async-failure-calls-debug-logger-when-feature-loaded ()
  "Normal: when the chime-debug feature is loaded, the debug logger is invoked."
  (let ((logged nil)
        (chime--consecutive-async-failures 0)
        (chime-max-consecutive-failures 0)
        (chime-modeline-no-events-text " ⏰")
        (chime-modeline-string nil))
    (cl-letf (((symbol-function 'featurep)
               (lambda (feat &rest _) (eq feat 'chime-debug)))
              ((symbol-function 'chime--debug-log-async-error)
               (lambda (err) (setq logged err)))
              ((symbol-function 'force-mode-line-update) (lambda (&optional _))))
      (chime--record-async-failure '(error "boom") "Async error"))
    (should (equal '(error "boom") logged))))

;;;; chime--log-silently mid-line branch (point not at BOL)

(ert-deftest test-chime-log-silently-inserts-leading-newline-when-not-at-bol ()
  "Boundary: when *Messages* tail is mid-line, log-silently inserts a leading newline."
  (with-current-buffer (get-buffer-create "*Messages*")
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (insert "no-newline-prefix")
      (let ((pos-before (point-max)))
        (chime--log-silently "edge-coverage")
        (goto-char pos-before)
        ;; The inserted newline separates the two strings.
        (should (looking-at "\n"))
        (should (search-forward "edge-coverage" nil t))))))

(provide 'test-chime-edge-coverage)
;;; test-chime-edge-coverage.el ends here
