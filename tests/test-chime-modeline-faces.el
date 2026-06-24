;;; test-chime-modeline-faces.el --- Tests for themeable modeline faces -*- lexical-binding: t; -*-

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

;; Unit tests for chime's themeable modeline faces:
;; - the four deffaces are defined
;; - chime--modeline-urgency-face maps minutes-until to the right face
;; - chime--propertize-modeline-string applies a passed face
;; - chime--render-modeline-string applies the urgency / no-events faces

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'testutil-time (expand-file-name "testutil-time.el"))
(require 'testutil-events (expand-file-name "testutil-events.el"))

;;; Setup/Teardown

(defun test-chime-faces-setup ()
  "Set tooltip formats so render paths produce a tooltip string."
  (chime-create-test-base-dir)
  (setq chime-tooltip-header-format "Upcoming Events as of %a %b %d %Y @ %I:%M %p")
  (setq chime-display-time-format-string "%I:%M %p")
  (setq chime-time-left-formats
        (list (cons 'at-event "right now")
              (cons 'short    "in %M")
              (cons 'long     "in %H %M"))))

(defun test-chime-faces-teardown ()
  "Teardown."
  (chime-delete-test-base-dir)
  (setq chime--upcoming-events nil))

;;; Faces are defined

(ert-deftest test-chime-modeline-faces-are-defined ()
  "Normal: chime defines the four themeable modeline faces."
  (should (facep 'chime-modeline-face))
  (should (facep 'chime-modeline-soon-face))
  (should (facep 'chime-modeline-urgent-face))
  (should (facep 'chime-modeline-no-events-face)))

;;; Urgency-face mapping — Normal

(ert-deftest test-chime-modeline-urgency-face-default-when-distant ()
  "Normal: an event beyond the soon threshold maps to the default face."
  (let ((chime-modeline-urgent-threshold-minutes 5)
        (chime-modeline-soon-threshold-minutes 30))
    (should (eq 'chime-modeline-face (chime--modeline-urgency-face 60)))))

(ert-deftest test-chime-modeline-urgency-face-soon ()
  "Normal: an event inside the soon window maps to the soon face."
  (let ((chime-modeline-urgent-threshold-minutes 5)
        (chime-modeline-soon-threshold-minutes 30))
    (should (eq 'chime-modeline-soon-face (chime--modeline-urgency-face 20)))))

(ert-deftest test-chime-modeline-urgency-face-urgent ()
  "Normal: an imminent event maps to the urgent face."
  (let ((chime-modeline-urgent-threshold-minutes 5)
        (chime-modeline-soon-threshold-minutes 30))
    (should (eq 'chime-modeline-urgent-face (chime--modeline-urgency-face 2)))))

;;; Urgency-face mapping — Boundary

(ert-deftest test-chime-modeline-urgency-face-at-urgent-threshold ()
  "Boundary: minutes exactly at the urgent threshold is urgent."
  (let ((chime-modeline-urgent-threshold-minutes 5)
        (chime-modeline-soon-threshold-minutes 30))
    (should (eq 'chime-modeline-urgent-face (chime--modeline-urgency-face 5)))))

(ert-deftest test-chime-modeline-urgency-face-at-soon-threshold ()
  "Boundary: minutes exactly at the soon threshold is soon."
  (let ((chime-modeline-urgent-threshold-minutes 5)
        (chime-modeline-soon-threshold-minutes 30))
    (should (eq 'chime-modeline-soon-face (chime--modeline-urgency-face 30)))))

(ert-deftest test-chime-modeline-urgency-face-zero-is-urgent ()
  "Boundary: an event happening now (0 minutes) is urgent."
  (let ((chime-modeline-urgent-threshold-minutes 5)
        (chime-modeline-soon-threshold-minutes 30))
    (should (eq 'chime-modeline-urgent-face (chime--modeline-urgency-face 0)))))

(ert-deftest test-chime-modeline-urgency-face-fractional-minutes ()
  "Boundary: fractional minutes (minutes-until is a float) bucket correctly."
  (let ((chime-modeline-urgent-threshold-minutes 5)
        (chime-modeline-soon-threshold-minutes 30))
    (should (eq 'chime-modeline-urgent-face (chime--modeline-urgency-face 4.5)))
    (should (eq 'chime-modeline-soon-face (chime--modeline-urgency-face 5.5)))))

;;; propertize applies face

(ert-deftest test-chime-propertize-applies-face-when-passed ()
  "Normal: a non-nil FACE argument becomes the `face' text property."
  (test-chime-faces-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (event-time (time-add now (seconds-to-time 120)))
             (ts (test-timestamp-string event-time)))
        (setq chime--upcoming-events
              (list (list `((title . "Meeting") (times . ((,ts . ,event-time))))
                          (cons ts event-time) 2)))
        (with-test-time now
          (let ((result (chime--propertize-modeline-string
                         " ⏰ Meeting" 'chime-modeline-urgent-face)))
            (should (eq 'chime-modeline-urgent-face
                        (get-text-property 0 'face result))))))
    (test-chime-faces-teardown)))

(ert-deftest test-chime-propertize-no-face-when-omitted ()
  "Boundary: with no FACE argument, no `face' property is added."
  (test-chime-faces-setup)
  (unwind-protect
      (let* ((now (test-time-now))
             (event-time (time-add now (seconds-to-time 1800)))
             (ts (test-timestamp-string event-time)))
        (setq chime--upcoming-events
              (list (list `((title . "Meeting") (times . ((,ts . ,event-time))))
                          (cons ts event-time) 30)))
        (with-test-time now
          (let ((result (chime--propertize-modeline-string " ⏰ Meeting")))
            (should-not (get-text-property 0 'face result)))))
    (test-chime-faces-teardown)))

;;; render applies the urgency / no-events faces

(ert-deftest test-chime-render-applies-urgency-face-to-soonest ()
  "Normal: render applies the urgency face matching the soonest event."
  (test-chime-faces-setup)
  (unwind-protect
      (let* ((chime-modeline-urgent-threshold-minutes 5)
             (chime-modeline-soon-threshold-minutes 30)
             (chime-modeline-format " ⏰ %s")
             (now (test-time-now))
             (event-time (time-add now (seconds-to-time 120)))
             (ts (test-timestamp-string event-time))
             (soonest (list `((title . "Meeting")) ts 2 "Meeting in 2 min")))
        (setq chime--upcoming-events
              (list (list `((title . "Meeting") (times . ((,ts . ,event-time))))
                          (cons ts event-time) 2)))
        (with-test-time now
          (let ((result (chime--render-modeline-string
                         soonest chime--upcoming-events 168)))
            (should (eq 'chime-modeline-urgent-face
                        (get-text-property 0 'face result))))))
    (test-chime-faces-teardown)))

(ert-deftest test-chime-render-no-events-applies-no-events-face ()
  "Normal: the no-events modeline applies the no-events face."
  (test-chime-faces-setup)
  (unwind-protect
      (let ((chime-modeline-no-events-text " ⏰")
            (now (test-time-now)))
        (setq chime--upcoming-events nil)
        (with-test-time now
          (let ((result (chime--render-modeline-string nil nil 168)))
            (should (eq 'chime-modeline-no-events-face
                        (get-text-property 0 'face result))))))
    (test-chime-faces-teardown)))

(provide 'test-chime-modeline-faces)
;;; test-chime-modeline-faces.el ends here
