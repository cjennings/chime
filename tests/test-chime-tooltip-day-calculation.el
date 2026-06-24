;;; test-chime-tooltip-day-calculation.el --- Tests for tooltip day/hour calculation -*- lexical-binding: t; -*-

;;; Commentary:
;; Comprehensive tests for tooltip time-until formatting, especially day/hour calculations.
;;
;; Tests cover:
;; - Boundary cases (23h59m, 24h, 25h)
;; - Midnight boundaries
;; - Multiple days with fractional hours
;; - Exact day boundaries (48h, 72h)
;; - Edge cases that could trigger truncation bugs

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-events (expand-file-name "testutil-events.el"))

(defmacro test-chime-tooltip-day-calculation--with-tooltip (now content &rest body)
  "Bind tooltip for CONTENT at NOW and run BODY with common test config."
  (declare (indent 2))
  `(with-test-setup
     (with-chime-config
       chime-modeline-lookahead-minutes 10080
       chime-tooltip-lookahead-hours 168
       (with-test-time ,now
         (with-chime-tooltip-from-content ,content tooltip
           ,@body)))))

(ert-deftest test-chime-tooltip-day-calculation-fractional-days ()
  "Test that fractional days show both days and hours correctly.

User scenario: Viewing tooltip on Sunday 9pm, sees:
- Tuesday 9pm event: 48 hours = exactly 2 days → 'in 2 days'
- Wednesday 2pm event: 65 hours = 2.7 days → 'in 2 days 17 hours'

This test prevents regression of the integer division truncation bug."
  (let* ((now (test-time-today-at 21 0))  ; Sunday 9pm
         ;; Create events at specific future times
         (tuesday-9pm (time-add now (seconds-to-time (* 48 3600))))   ; +48 hours
         (wednesday-2pm (time-add now (seconds-to-time (* 65 3600)))) ; +65 hours
         (content (format "* Tuesday Event\n<%s>\n* Wednesday Event\n<%s>\n"
                          (format-time-string "<%Y-%m-%d %a %H:%M>" tuesday-9pm)
                          (format-time-string "<%Y-%m-%d %a %H:%M>" wednesday-2pm))))
    (test-chime-tooltip-day-calculation--with-tooltip now content
      (ert-info ((format "Tooltip content:\n%s" tooltip))
        ;; Verify tooltip contains both events
        (should (string-match-p "Tuesday Event" tooltip))
        (should (string-match-p "Wednesday Event" tooltip))

        ;; AFTER FIX: Tuesday shows "in 2 days", Wednesday shows "in 2 days 17 hours"
        ;; Verify Tuesday shows exactly 2 days (no "hours" in countdown)
        (should (string-match-p "Tuesday Event.*(in 2 days)" tooltip))
        ;; Make sure Tuesday doesn't have hours
        (should-not (string-match-p "Tuesday Event.*hours" tooltip))

        ;; Verify Wednesday shows 2 days AND 17 hours
        (should (string-match-p "Wednesday Event.*(in 2 days 17 hours)" tooltip))

        ;; Verify they show DIFFERENT countdowns
        (let ((tuesday-line (progn
                             (string-match "Tuesday Event[^\n]*" tooltip)
                             (match-string 0 tooltip)))
              (wednesday-line (progn
                               (string-match "Wednesday Event[^\n]*" tooltip)
                               (match-string 0 tooltip))))
          (should-not (string= tuesday-line wednesday-line)))))))

;;; Helper function for creating test events

(defun test-chime-tooltip-day-calculation--create-event-at-hours (base-time title hours-from-now)
  "Create event with TITLE at HOURS-FROM-NOW hours from BASE-TIME.
Returns formatted org content string."
  (let* ((event-time (time-add base-time (seconds-to-time (* hours-from-now 3600)))))
    (format "* %s\n<%s>\n"
            title
            (format-time-string "%Y-%m-%d %a %H:%M" event-time))))

(defun test-chime-tooltip-day-calculation--get-formatted-line (tooltip event-name)
  "Extract the formatted countdown line for EVENT-NAME from TOOLTIP."
  (when (string-match (format "%s[^\n]*" event-name) tooltip)
    (match-string 0 tooltip)))

;;; Boundary Cases - Critical thresholds

(ert-deftest test-chime-tooltip-day-calculation-boundary-exactly-24-hours ()
  "Test event exactly 24 hours away shows 'in 1 day' not hours."
  (let* ((now (test-time-today-at 12 0))
         (content (test-chime-tooltip-day-calculation--create-event-at-hours
                   now "Tomorrow Same Time" 24)))
    (test-chime-tooltip-day-calculation--with-tooltip now content
      ;; Should show "in 1 day" not hours
      (should (string-match-p "(in 1 day)" tooltip))
      (should-not (string-match-p "hours" tooltip)))))

(ert-deftest test-chime-tooltip-day-calculation-boundary-23-hours-59-minutes ()
  "Test event 23h59m away shows hours, not days (just under 24h threshold)."
  (let* ((now (test-time-today-at 12 0))
         ;; 23 hours 59 minutes = 1439 minutes = just under 1440
         (event-time (time-add now (seconds-to-time (* 1439 60))))
         (content (format "* Almost Tomorrow\n<%s>\n"
                          (format-time-string "%Y-%m-%d %a %H:%M" event-time))))
    (test-chime-tooltip-day-calculation--with-tooltip now content
      ;; Should show hours format (< 24 hours)
      (should (string-match-p "hours" tooltip))
      (should-not (string-match-p "days?" tooltip)))))

(ert-deftest test-chime-tooltip-day-calculation-boundary-25-hours ()
  "Test event 25 hours away shows 'in 1 day 1 hour'."
  (let* ((now (test-time-today-at 12 0))
         (content (test-chime-tooltip-day-calculation--create-event-at-hours
                   now "Day Plus One" 25)))
    (test-chime-tooltip-day-calculation--with-tooltip now content
      ;; Should show "in 1 day 1 hour"
      (should (string-match-p "(in 1 day 1 hour)" tooltip)))))

(ert-deftest test-chime-tooltip-day-calculation-boundary-exactly-48-hours ()
  "Test event exactly 48 hours away shows 'in 2 days' without hours."
  (let* ((now (test-time-today-at 12 0))
         (content (test-chime-tooltip-day-calculation--create-event-at-hours
                   now "Two Days Exact" 48)))
    (test-chime-tooltip-day-calculation--with-tooltip now content
      (let ((line (test-chime-tooltip-day-calculation--get-formatted-line
                   tooltip "Two Days Exact")))
        ;; Should show exactly "in 2 days" with NO hours
        (should (string-match-p "(in 2 days)" tooltip))
        ;; Verify the line doesn't contain "hour" (would be "2 days 0 hours")
        (should-not (string-match-p "hour" line))))))

;;; Midnight Boundaries

(ert-deftest test-chime-tooltip-day-calculation-midnight-crossing-shows-correct-days ()
  "Test event crossing midnight boundary calculates days correctly.

Scenario: 11pm now, event at 2am (3 hours later, next calendar day)
Should show hours, not '1 day' since it's only 3 hours away."
  (let* ((now (test-time-today-at 23 0))  ; 11pm
         ;; 3 hours later = 2am next day
         (content (test-chime-tooltip-day-calculation--create-event-at-hours
                   now "Early Morning" 3)))
    (test-chime-tooltip-day-calculation--with-tooltip now content
      ;; Should show "in 3 hours" not "in 1 day"
      (should (string-match-p "3 hours" tooltip))
      (should-not (string-match-p "days?" tooltip)))))

(ert-deftest test-chime-tooltip-day-calculation-midnight-plus-one-day ()
  "Test event at midnight tomorrow (24h exactly) shows '1 day'."
  (let* ((now (test-time-today-at 0 0))  ; Midnight today
         (content (test-chime-tooltip-day-calculation--create-event-at-hours
                   now "Midnight Tomorrow" 24)))
    (test-chime-tooltip-day-calculation--with-tooltip now content
      (should (string-match-p "(in 1 day)" tooltip))
      (should-not (string-match-p "hour" tooltip)))))

;;; Multiple Events - Verify distinct formatting

(ert-deftest test-chime-tooltip-day-calculation-multiple-events-distinct ()
  "Test multiple events at different fractional-day offsets show distinct times."
  (let* ((now (test-time-today-at 12 0))
         (content (concat
                   (test-chime-tooltip-day-calculation--create-event-at-hours now "Event 1 Day" 24)
                   (test-chime-tooltip-day-calculation--create-event-at-hours now "Event 1.5 Days" 36)
                   (test-chime-tooltip-day-calculation--create-event-at-hours now "Event 2 Days" 48)
                   (test-chime-tooltip-day-calculation--create-event-at-hours now "Event 2.75 Days" 66))))
    (test-chime-tooltip-day-calculation--with-tooltip now content
      ;; Verify each event shows correctly
      (should (string-match-p "Event 1 Day.*(in 1 day)" tooltip))
      (should (string-match-p "Event 1.5 Days.*(in 1 day 12 hours)" tooltip))
      (should (string-match-p "Event 2 Days.*(in 2 days)" tooltip))
      (should (string-match-p "Event 2.75 Days.*(in 2 days 18 hours)" tooltip))

      ;; Verify they're all different
      (let ((lines (split-string tooltip "\n")))
        (let ((countdowns (cl-remove-if-not
                           (lambda (line) (string-match-p "Event.*day" line))
                           lines)))
          ;; Should have 4 distinct countdown lines
          (should (= 4 (length countdowns)))
          ;; All should be unique
          (should (= 4 (length (delete-dups (copy-sequence countdowns))))))))))

(provide 'test-chime-tooltip-day-calculation)
;;; test-chime-tooltip-day-calculation.el ends here
