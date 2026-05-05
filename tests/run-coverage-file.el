;;; run-coverage-file.el --- Undercover setup for per-file coverage runs -*- lexical-binding: t; -*-

;;; Commentary:
;; Loaded by `make coverage' before each test file runs, BEFORE
;; chime.el is loaded.  Instrumenting must happen first so the
;; subsequent load picks up the instrumented source.
;;
;; Coverage data is merged across per-file invocations into a single
;; simplecov JSON at .coverage/simplecov.json (under the project root).

;;; Code:

(unless (require 'undercover nil t)
  (message "")
  (message "ERROR: undercover not installed.")
  (message "Run 'make setup' to install development dependencies.")
  (message "")
  (kill-emacs 1))

;; Resolve project root from this file's location so undercover patterns
;; and the report-file path don't depend on default-directory at load time.
(defvar run-coverage--project-root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name))))
  "Absolute path to the chime project root.")

;; Force coverage collection in non-CI environments.  Must be set after
;; loading undercover because the library's top-level form
;; `(setq undercover-force-coverage (getenv "UNDERCOVER_FORCE"))' would
;; otherwise overwrite the value.
(setq undercover-force-coverage t)

;; Local runs emit simplecov for whatever local tooling wants it.  CI sets
;; CI=true (GitHub Actions does this automatically), so we emit a coveralls
;; JSON instead and leave it on disk for the upload action to pick up.
;; The `undercover' macro splices each configuration list into `(list ,@it)',
;; which evaluates the elements.  Wildcard strings have to stay atoms — using
;; `(:files ...)' form lets us evaluate `expand-file-name' to an absolute path.
(undercover (:files (expand-file-name "chime.el" run-coverage--project-root))
            (:report-format (if (getenv "CI") 'coveralls 'simplecov))
            (:report-file (expand-file-name
                           (if (getenv "CI")
                               ".coverage/coveralls.json"
                             ".coverage/simplecov.json")
                           run-coverage--project-root))
            (:merge-report t)
            (:send-report nil))

;;; run-coverage-file.el ends here
