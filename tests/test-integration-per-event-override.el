;;; test-integration-per-event-override.el --- :CHIME_NOTIFY_BEFORE: through the agenda -*- lexical-binding: t; -*-

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

;; Slow integration test for the per-event :CHIME_NOTIFY_BEFORE: override.
;;
;; The unit tests call `chime--gather-info' on a hand-made org marker.  This
;; test goes one layer up: it puts a SCHEDULED heading with the property in an
;; org file, runs `org-agenda-list', and gathers events the same way
;; `chime--retrieve-events' does in the async child (split the agenda buffer
;; into lines, pull the `org-marker' from each, drop nils, map
;; `chime--gather-info').  The resulting event should carry ((30 . medium)),
;; not the global `chime-alert-intervals'.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-general (expand-file-name "testutil-general.el"))
(require 'cl-lib)

(defun test-integration-per-event-override--events-from-agenda ()
  "Run `org-agenda-list' and gather events the way `chime--retrieve-events' does.
Mirrors that function's marker-extraction chain; filters are skipped because
nothing is configured here."
  (org-agenda-list 8 (org-read-date nil nil "today"))
  (mapcar #'chime--gather-info
          (delq nil
                (mapcar (lambda (line)
                          (plist-get (org-fix-agenda-info (text-properties-at 0 line))
                                     'org-marker))
                        (org-split-string (buffer-string) "\n")))))

(ert-deftest test-integration-per-event-override-applies-through-agenda ()
  "Slow: a SCHEDULED heading with :CHIME_NOTIFY_BEFORE: 30 gathers with ((30 . medium))."
  :tags '(:slow)
  (let* ((scheduled (format-time-string
                     "SCHEDULED: <%Y-%m-%d %a 10:00>"
                     (time-add (current-time) (days-to-time 1))))
         (content (format "* Important meeting\n:PROPERTIES:\n:CHIME_NOTIFY_BEFORE: 30\n:END:\n%s\n"
                          scheduled))
         ;; org-agenda only recognizes files matching `org-agenda-file-regexp'
         ;; (ending in .org), so make the temp file a real .org file.
         (org-file (make-temp-file
                    (expand-file-name "chime-perevent-" (chime-create-test-base-dir))
                    nil ".org" content))
         (org-agenda-files (list org-file))
         (org-agenda-use-time-grid nil)
         (org-agenda-compact-blocks t))
    (unwind-protect
        (let ((events (test-integration-per-event-override--events-from-agenda)))
          (should (cl-some (lambda (e)
                             (and (string= "Important meeting" (chime--event-title e))
                                  (equal '((30 . medium)) (chime--event-intervals e))))
                           events)))
      (when (get-buffer "*Org Agenda*")
        (kill-buffer "*Org Agenda*"))
      (when (find-buffer-visiting org-file)
        (kill-buffer (find-buffer-visiting org-file)))
      (chime-delete-test-base-dir))))

(provide 'test-integration-per-event-override)
;;; test-integration-per-event-override.el ends here
