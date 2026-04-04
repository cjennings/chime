;;; test-bootstrap.el --- Common test initialization for chime -*- lexical-binding: t; -*-

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
