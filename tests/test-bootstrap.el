;;; test-bootstrap.el --- Common test initialization for chime -*- lexical-binding: t; -*-

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

;; Shared initialization for all chime test files.
;; Handles package setup, dependency loading, and chime initialization.
;;
;; Usage: (require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
;;
;; For debug tests, set chime-debug BEFORE requiring this file:
;;   (setq chime-debug t)
;;   (require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Code:

;; Initialize package system for batch mode
(when noninteractive
  (package-initialize))

(require 'ert)

;; Load dependencies required by chime
(require 'dash)
(require 'alert)
(require 'async)
(require 'org-agenda)

;; Load chime from parent directory
(load (expand-file-name "../chime.el") nil t)

(provide 'test-bootstrap)
;;; test-bootstrap.el ends here
