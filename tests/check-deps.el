;;; check-deps.el --- Verify test dependencies are loadable -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Loaded by tests/Makefile's check-deps target after eask has prepared the
;; test environment.  Keep dependency discovery inside Emacs so package.el,
;; package-vc, Eask, Nix, and pre-populated load-path setups all work the same
;; way: a dependency is available if Emacs can require it.

;;; Code:

(when noninteractive
  (package-initialize))

(defconst chime-check-deps-required-features
  '(dash alert async org-agenda)
  "Features required by the Chime test suite.")

(defun chime-check-deps--missing-features ()
  "Return required test features that cannot be loaded."
  (let (missing)
    (dolist (feature chime-check-deps-required-features (nreverse missing))
      (unless (require feature nil t)
        (push feature missing)))))

(let ((missing (chime-check-deps--missing-features)))
  (if missing
      (progn
        (message "Missing Emacs Lisp test dependencies: %s"
                 (mapconcat #'symbol-name missing ", "))
        (message "Run `make setup' from the project root, or make these features available on load-path.")
        (kill-emacs 1))
    (message "Required Emacs Lisp dependencies are loadable: %s"
             (mapconcat #'symbol-name chime-check-deps-required-features ", "))))

;;; check-deps.el ends here
