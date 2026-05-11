;;; test-chime-intervals-for-marker.el --- Tests for per-event interval override -*- lexical-binding: t; -*-

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

;; Tests for the per-event :CHIME_NOTIFY_BEFORE: property override and the
;; deprecated :WILD_NOTIFIER_NOTIFY_BEFORE: alias:
;;
;; - chime--parse-notify-before-value : value-string parsing
;; - chime--intervals-for-marker       : property lookup with fallback to
;;                                       chime-alert-intervals; returns
;;                                       (INTERVALS . DEPRECATED-PROP)
;; - chime--gather-info                : end-to-end gather honoring the property
;; - chime--maybe-warn-deprecated-properties : one-warning-per-session guard

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'cl-lib)

;;; Helpers

(defun test-chime-intervals--org-heading-with-props (props)
  "Return org content for one heading whose drawer carries PROPS.
PROPS is a list of (NAME . VALUE) string pairs, or nil for no drawer."
  (concat "* Test Heading\n"
          (when props
            (concat ":PROPERTIES:\n"
                    (mapconcat (lambda (p) (format ":%s: %s\n" (car p) (cdr p)))
                               props "")
                    ":END:\n"))
          "<2026-05-12 Tue 14:00>\n"))

(defmacro test-chime-intervals--with-marker (props &rest body)
  "Run BODY in a temp org buffer with a heading carrying PROPS; bind `marker'."
  (declare (indent 1) (debug t))
  `(with-temp-buffer
     (org-mode)
     (insert (test-chime-intervals--org-heading-with-props ,props))
     (goto-char (point-min))
     (let ((marker (point-marker)))
       ,@body)))

(defmacro test-chime-intervals--capture-messages (var &rest body)
  "Run BODY with `message' calls captured into VAR (chronological)."
  (declare (indent 1) (debug t))
  `(let ((,var nil))
     (cl-letf (((symbol-function 'message)
                (lambda (fmt &rest args)
                  (push (apply #'format fmt args) ,var))))
       ,@body)
     (setq ,var (nreverse ,var))))

;;; chime--parse-notify-before-value

(ert-deftest test-chime-parse-notify-before-value-normal-and-boundary ()
  "Normal/Boundary: non-negative integer strings parse to integers."
  (dolist (case '(("30" . 30) ("0" . 0) (" 30 " . 30) ("007" . 7) ("1440" . 1440)))
    (should (= (cdr case)
               (chime--parse-notify-before-value (car case))))))

(ert-deftest test-chime-parse-notify-before-value-error-cases ()
  "Error: non-integer, negative, fractional, empty, suffixed, and nil values yield nil."
  (dolist (bad '("abc" "-5" "30.5" "" "   " "30m" nil))
    (should-not (chime--parse-notify-before-value bad))))

;;; chime--intervals-for-marker

(ert-deftest test-chime-intervals-for-marker-normal-no-property-uses-global ()
  "Normal: with no override property, returns (chime-alert-intervals . nil)."
  (let ((chime-alert-intervals '((10 . medium) (0 . high))))
    (test-chime-intervals--with-marker nil
      (should (equal (cons '((10 . medium) (0 . high)) nil)
                     (chime--intervals-for-marker marker))))))

(ert-deftest test-chime-intervals-for-marker-normal-canonical-property ()
  "Normal: :CHIME_NOTIFY_BEFORE: 30 yields (((30 . medium)) . nil)."
  (test-chime-intervals--with-marker '(("CHIME_NOTIFY_BEFORE" . "30"))
    (should (equal (cons '((30 . medium)) nil)
                   (chime--intervals-for-marker marker)))))

(ert-deftest test-chime-intervals-for-marker-normal-deprecated-alias ()
  "Normal: :WILD_NOTIFIER_NOTIFY_BEFORE: 15 yields the override and flags the alias."
  (test-chime-intervals--with-marker '(("WILD_NOTIFIER_NOTIFY_BEFORE" . "15"))
    (should (equal (cons '((15 . medium)) "WILD_NOTIFIER_NOTIFY_BEFORE")
                   (chime--intervals-for-marker marker)))))

(ert-deftest test-chime-intervals-for-marker-normal-canonical-wins-over-alias ()
  "Normal: with both properties set, the canonical one wins and the alias is not flagged."
  (test-chime-intervals--with-marker '(("CHIME_NOTIFY_BEFORE" . "5")
                                       ("WILD_NOTIFIER_NOTIFY_BEFORE" . "60"))
    (should (equal (cons '((5 . medium)) nil)
                   (chime--intervals-for-marker marker)))))

(ert-deftest test-chime-intervals-for-marker-boundary-zero ()
  "Boundary: :CHIME_NOTIFY_BEFORE: 0 means notify at event time."
  (test-chime-intervals--with-marker '(("CHIME_NOTIFY_BEFORE" . "0"))
    (should (equal (cons '((0 . medium)) nil)
                   (chime--intervals-for-marker marker)))))

(ert-deftest test-chime-intervals-for-marker-error-malformed-canonical-falls-back ()
  "Error: a malformed :CHIME_NOTIFY_BEFORE: value logs and falls back to the global."
  (let ((chime-alert-intervals '((10 . medium))))
    (test-chime-intervals--with-marker '(("CHIME_NOTIFY_BEFORE" . "soon"))
      (test-chime-intervals--capture-messages messages
        (should (equal (cons '((10 . medium)) nil)
                       (chime--intervals-for-marker marker))))
      (should (cl-some (lambda (m) (string-match-p "CHIME_NOTIFY_BEFORE" m)) messages)))))

(ert-deftest test-chime-intervals-for-marker-error-malformed-alias-falls-back ()
  "Error: a malformed deprecated-alias value logs and falls back to the global."
  (let ((chime-alert-intervals '((10 . medium))))
    (test-chime-intervals--with-marker '(("WILD_NOTIFIER_NOTIFY_BEFORE" . "-3"))
      (test-chime-intervals--capture-messages messages
        (should (equal (cons '((10 . medium)) nil)
                       (chime--intervals-for-marker marker))))
      (should (cl-some (lambda (m) (string-match-p "WILD_NOTIFIER_NOTIFY_BEFORE" m)) messages)))))

;;; chime--gather-info integration

(ert-deftest test-chime-gather-info-integration-applies-canonical-override ()
  "Integration: a heading with :CHIME_NOTIFY_BEFORE: 25 gathers an event with ((25 . medium))."
  (with-temp-buffer
    (org-mode)
    (insert "* Meeting\n:PROPERTIES:\n:CHIME_NOTIFY_BEFORE: 25\n:END:\n<2026-05-12 Tue 14:00>\n")
    (goto-char (point-min))
    (let ((event (chime--gather-info (point-marker))))
      (should (equal '((25 . medium)) (chime--event-intervals event)))
      (should-not (chime--event-deprecated-property event)))))

(ert-deftest test-chime-gather-info-integration-flags-deprecated-alias ()
  "Integration: a heading with the deprecated alias gathers an event carrying the deprecation flag."
  (with-temp-buffer
    (org-mode)
    (insert "* Meeting\n:PROPERTIES:\n:WILD_NOTIFIER_NOTIFY_BEFORE: 20\n:END:\n<2026-05-12 Tue 14:00>\n")
    (goto-char (point-min))
    (let ((event (chime--gather-info (point-marker))))
      (should (equal '((20 . medium)) (chime--event-intervals event)))
      (should (string= "WILD_NOTIFIER_NOTIFY_BEFORE"
                       (chime--event-deprecated-property event))))))

(ert-deftest test-chime-gather-info-integration-no-override-uses-global ()
  "Integration: a heading without the property gathers with chime-alert-intervals."
  (let ((chime-alert-intervals '((10 . medium) (0 . high))))
    (with-temp-buffer
      (org-mode)
      (insert "* Meeting\n<2026-05-12 Tue 14:00>\n")
      (goto-char (point-min))
      (let ((event (chime--gather-info (point-marker))))
        (should (equal '((10 . medium) (0 . high)) (chime--event-intervals event)))
        (should-not (chime--event-deprecated-property event))))))

;;; chime--maybe-warn-deprecated-properties

(ert-deftest test-chime-maybe-warn-deprecated-properties-normal-warns-once ()
  "Normal: the first events list carrying a deprecated property triggers one warning."
  (let ((chime--deprecated-property-warned nil)
        (warned nil))
    (cl-letf (((symbol-function 'display-warning)
               (lambda (_type msg &rest _) (push msg warned))))
      (chime--maybe-warn-deprecated-properties
       (list (chime--make-event '(("<2026-05-12 Tue 14:00>" . (1 2))) "A" '((10 . medium)))
             (chime--make-event '(("<2026-05-12 Tue 15:00>" . (3 4))) "B" '((20 . medium))
                                nil nil "WILD_NOTIFIER_NOTIFY_BEFORE")))
      (should (= 1 (length warned)))
      (should chime--deprecated-property-warned)
      (should (string-match-p "WILD_NOTIFIER_NOTIFY_BEFORE" (car warned))))))

(ert-deftest test-chime-maybe-warn-deprecated-properties-boundary-no-deprecated-no-warning ()
  "Boundary: events with no deprecated property produce no warning, guard stays nil."
  (let ((chime--deprecated-property-warned nil)
        (warned nil))
    (cl-letf (((symbol-function 'display-warning)
               (lambda (&rest _) (push t warned))))
      (chime--maybe-warn-deprecated-properties
       (list (chime--make-event '(("<2026-05-12 Tue 14:00>" . (1 2))) "A" '((10 . medium)))))
      (should (null warned))
      (should-not chime--deprecated-property-warned))))

(ert-deftest test-chime-maybe-warn-deprecated-properties-boundary-already-warned-no-repeat ()
  "Boundary: once the session guard is set, no further warning fires."
  (let ((chime--deprecated-property-warned t)
        (warned nil))
    (cl-letf (((symbol-function 'display-warning)
               (lambda (&rest _) (push t warned))))
      (chime--maybe-warn-deprecated-properties
       (list (chime--make-event '(("<2026-05-12 Tue 14:00>" . (1 2))) "A" '((20 . medium))
                                nil nil "WILD_NOTIFIER_NOTIFY_BEFORE")))
      (should (null warned)))))

(provide 'test-chime-intervals-for-marker)
;;; test-chime-intervals-for-marker.el ends here
