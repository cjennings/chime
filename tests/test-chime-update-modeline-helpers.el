;;; test-chime-update-modeline-helpers.el --- Tests for modeline helper functions -*- lexical-binding: t; -*-

;;; Commentary:
;; Unit tests for the refactored modeline helper functions:
;; - chime--find-soonest-time-in-window
;; - chime--build-upcoming-events-list
;; - chime--find-soonest-modeline-event
;; - chime--render-modeline-string

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))
(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'testutil-events (expand-file-name "testutil-events.el"))

;;;; Tests for chime--find-soonest-time-in-window

(ert-deftest test-chime-find-soonest-time-empty-list ()
  "Test that empty times list returns nil."
  (let ((now (test-time-now))
        (times '()))
    (should (null (chime--find-soonest-time-in-window times now 60)))))

(ert-deftest test-chime-find-soonest-time-single-within-window ()
  "Test single time within window returns that time."
  (let* ((now (test-time-now))
         (event-time (time-add now (seconds-to-time 1800))) ; 30 minutes
         (times (list (cons "<2025-01-01 Wed 12:30>" event-time))))
    (let ((result (chime--find-soonest-time-in-window times now 60)))
      (should result)
      (should (equal (nth 0 result) "<2025-01-01 Wed 12:30>"))
      (should (time-equal-p (nth 1 result) event-time))
      (should (< (abs (- (nth 2 result) 30)) 1))))) ; ~30 minutes

(ert-deftest test-chime-find-soonest-time-multiple-returns-soonest ()
  "Test multiple times returns the soonest one."
  (let* ((now (test-time-now))
         (time1 (time-add now (seconds-to-time 3600))) ; 60 min
         (time2 (time-add now (seconds-to-time 1800))) ; 30 min (soonest)
         (time3 (time-add now (seconds-to-time 5400))) ; 90 min
         (times (list (cons "<2025-01-01 Wed 13:00>" time1)
                      (cons "<2025-01-01 Wed 12:30>" time2)
                      (cons "<2025-01-01 Wed 13:30>" time3))))
    (let ((result (chime--find-soonest-time-in-window times now 120)))
      (should result)
      (should (equal (nth 0 result) "<2025-01-01 Wed 12:30>"))
      (should (< (abs (- (nth 2 result) 30)) 1))))) ; ~30 minutes

(ert-deftest test-chime-find-soonest-time-outside-window ()
  "Test times outside window returns nil."
  (let* ((now (test-time-now))
         (event-time (time-add now (seconds-to-time 7200))) ; 120 minutes
         (times (list (cons "<2025-01-01 Wed 14:00>" event-time))))
    (should (null (chime--find-soonest-time-in-window times now 60)))))

(ert-deftest test-chime-find-soonest-time-mix-inside-outside ()
  "Test mix of times inside/outside window returns soonest inside."
  (let* ((now (test-time-now))
         (time-outside (time-add now (seconds-to-time 7200))) ; 120 min (outside)
         (time-inside (time-add now (seconds-to-time 1800)))  ; 30 min (inside, soonest)
         (times (list (cons "<2025-01-01 Wed 14:00>" time-outside)
                      (cons "<2025-01-01 Wed 12:30>" time-inside))))
    (let ((result (chime--find-soonest-time-in-window times now 60)))
      (should result)
      (should (equal (nth 0 result) "<2025-01-01 Wed 12:30>")))))

(ert-deftest test-chime-find-soonest-time-past-event ()
  "Test past events are excluded."
  (let* ((now (test-time-now))
         (past-time (time-subtract now (seconds-to-time 1800))) ; -30 minutes
         (times (list (cons "<2025-01-01 Wed 11:30>" past-time))))
    (should (null (chime--find-soonest-time-in-window times now 60)))))

;;;; Tests for chime--build-upcoming-events-list

(ert-deftest test-chime-build-upcoming-empty-events ()
  "Test empty events list returns empty."
  (let ((now (test-time-now))
        (events '()))
    (should (null (chime--build-upcoming-events-list events now 1440 t)))))

(ert-deftest test-chime-build-upcoming-single-event ()
  "Test single event within window is included."
  (with-test-setup
    (let* ((now (test-time-now))
           (event-time (time-add now (seconds-to-time 1800)))
           (content (test-create-org-event "Meeting" event-time))
           (events (test-gather-events-from-content content))
           (result (chime--build-upcoming-events-list events now 1440 t)))
      (should (= (length result) 1))
      (should (string= (cdr (assoc 'title (car (car result)))) "Meeting")))))

(ert-deftest test-chime-build-upcoming-sorted-by-time ()
  "Test multiple events are sorted by time (soonest first)."
  (with-test-setup
    (let* ((now (test-time-now))
           (time1 (time-add now (seconds-to-time 5400))) ; 90 min
           (time2 (time-add now (seconds-to-time 1800))) ; 30 min (soonest)
           (time3 (time-add now (seconds-to-time 3600))) ; 60 min
           (content (test-create-org-events
                     `(("Meeting 1" ,time1)
                       ("Meeting 2" ,time2)
                       ("Meeting 3" ,time3))))
           (events (test-gather-events-from-content content))
           (result (chime--build-upcoming-events-list events now 1440 t)))
      (should (= (length result) 3))
      ;; First should be Meeting 2 (soonest at 30 min)
      (should (string= (cdr (assoc 'title (car (nth 0 result)))) "Meeting 2"))
      ;; Second should be Meeting 3 (60 min)
      (should (string= (cdr (assoc 'title (car (nth 1 result)))) "Meeting 3"))
      ;; Third should be Meeting 1 (90 min)
      (should (string= (cdr (assoc 'title (car (nth 2 result)))) "Meeting 1")))))

(ert-deftest test-chime-build-upcoming-excludes-outside-window ()
  "Test events outside lookahead window are excluded."
  (with-test-setup
    (let* ((now (test-time-now))
           (near-time (time-add now (seconds-to-time 1800)))   ; 30 min (included)
           (far-time (time-add now (seconds-to-time 10800)))   ; 180 min (excluded)
           (content (test-create-org-events
                     `(("Near Meeting" ,near-time)
                       ("Far Meeting" ,far-time))))
           (events (test-gather-events-from-content content))
           (result (chime--build-upcoming-events-list events now 60 t))) ; 60 min window
      (should (= (length result) 1))
      (should (string= (cdr (assoc 'title (car (car result)))) "Near Meeting")))))

;;;; Tests for chime--find-soonest-modeline-event

(ert-deftest test-chime-find-soonest-modeline-empty-events ()
  "Test empty events list returns nil."
  (let ((now (test-time-now))
        (events '()))
    (should (null (chime--find-soonest-modeline-event events now 60)))))

(ert-deftest test-chime-find-soonest-modeline-single-timed-event ()
  "Test single timed event within window is returned."
  (with-test-setup
    (let* ((now (test-time-now))
           (event-time (time-add now (seconds-to-time 1800)))
           (content (test-create-org-event "Meeting" event-time))
           (events (test-gather-events-from-content content))
           (result (chime--find-soonest-modeline-event events now 60)))
      (should result)
      (should (string= (cdr (assoc 'title (nth 0 result))) "Meeting")))))

(ert-deftest test-chime-find-soonest-modeline-excludes-all-day ()
  "Test all-day events are excluded from modeline."
  (with-test-setup
    (let* ((now (test-time-today-at 10 0))
           (all-day-time (test-time-today-at 0 0))
           (timed-time (time-add now (seconds-to-time 1800)))
           (content (test-create-org-events
                     `(("All Day Event" ,all-day-time nil t)
                       ("Timed Event" ,timed-time))))
           (events (test-gather-events-from-content content))
           (result (chime--find-soonest-modeline-event events now 60)))
      (should result)
      (should (string= (cdr (assoc 'title (nth 0 result))) "Timed Event")))))

;;;; Tests for chime--render-modeline-string

(ert-deftest test-chime-render-modeline-string-normal-soonest-returns-formatted-string ()
  "Normal: SOONEST branch formats event-text via `chime-modeline-format'."
  (let ((chime-modeline-format "[%s]")
        (chime--upcoming-events nil)
        (soonest '(event-placeholder "ts" 10 "Standup in 10 min")))
    (let ((result (chime--render-modeline-string soonest nil 60)))
      (should (stringp result))
      (should (string= result "[Standup in 10 min]")))))

(ert-deftest test-chime-render-modeline-string-normal-no-soonest-with-upcoming-binds-both-clicks ()
  "Normal: no SOONEST + UPCOMING propertizes no-events-text with mouse-1 and mouse-3."
  (let* ((chime-modeline-no-events-text "*")
         (event-time (current-time))
         (upcoming (list (list '((title . "Test"))
                               (cons "<2026-01-01 Thu 12:00>" event-time)
                               5)))
         (result (chime--render-modeline-string nil upcoming 60))
         (map (get-text-property 0 'local-map result)))
    (should (stringp result))
    (should (string= (substring-no-properties result) "*"))
    (should (eq (lookup-key map [mode-line mouse-1]) #'chime--open-calendar-url))
    (should (eq (lookup-key map [mode-line mouse-3]) #'chime--jump-to-first-event))
    (should (stringp (get-text-property 0 'help-echo result)))))

(ert-deftest test-chime-render-modeline-string-normal-no-soonest-no-upcoming-only-mouse-1 ()
  "Normal: no SOONEST + no UPCOMING binds only mouse-1, uses no-events-tooltip."
  (let* ((chime-modeline-no-events-text "*")
         (result (chime--render-modeline-string nil nil 60))
         (map (get-text-property 0 'local-map result))
         (tooltip (get-text-property 0 'help-echo result)))
    (should (stringp result))
    (should (eq (lookup-key map [mode-line mouse-1]) #'chime--open-calendar-url))
    (should-not (lookup-key map [mode-line mouse-3]))
    (should (string-match-p "No calendar events" tooltip))))

(ert-deftest test-chime-render-modeline-string-boundary-no-soonest-no-events-text-nil-returns-nil ()
  "Boundary: returns nil when no SOONEST and `chime-modeline-no-events-text' is nil."
  (let ((chime-modeline-no-events-text nil))
    (should (null (chime--render-modeline-string nil nil 60)))
    (should (null (chime--render-modeline-string nil '(some-upcoming) 60)))))

(ert-deftest test-chime-render-modeline-string-boundary-soonest-renders-when-no-events-text-nil ()
  "Boundary: SOONEST branch renders regardless of `chime-modeline-no-events-text'."
  (let ((chime-modeline-format "%s")
        (chime-modeline-no-events-text nil)
        (chime--upcoming-events nil)
        (soonest '(event-placeholder "ts" 10 "Event!")))
    (should (string= "Event!" (chime--render-modeline-string soonest nil 60)))))

(provide 'test-chime-update-modeline-helpers)
;;; test-chime-update-modeline-helpers.el ends here
