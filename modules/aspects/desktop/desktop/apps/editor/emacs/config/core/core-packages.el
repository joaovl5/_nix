;; init straight.el  -*- lexical-binding: t; -*-

;; Startup cost: with the default `find-at-startup', straight runs find(1)
;; over every repo in `straight/repos' on each startup (~17k files / 500M+
;; here).  Warm that is ~0.2s, cold (after a boot, or once the page cache
;; was evicted) it is seconds - the main source of the occasional slow
;; startups.  `check-on-save' notices packages edited inside this Emacs;
;; `find-when-checking' keeps the full scan for explicit
;; `straight-check-package' and `straight-check-all' calls.  This must
;; be set before straight.el is loaded.
(setq straight-check-for-modifications
      '(check-on-save find-when-checking))

(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el"
                         (or (bound-and-true-p straight-base-dir)
                             user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent
         'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Emacs 30 already ships `project' and `xref'.  Geiser's straight
;; dependencies installed GNU ELPA copies whose build directories
;; shadowed the already-loaded built-ins on `load-path'.  Eglot calls
;; `require-with-check' on both features and errors with "Feature
;; `project' is now provided by a different file ...", which surfaced as
;; "Initialization fails with: ..." when Org opened a src-block edit
;; buffer.  Treating the two proven conflicts as built-in keeps one copy.
;; This runs after bootstrap so straight's own pseudo-package defaults
;; are kept, and before the first package registration.
(dolist (pkg '(project xref))
  (add-to-list 'straight-built-in-pseudo-packages pkg))

;; Ensure straight's Org is registered before packages that may pull in built-in Org.
(straight-use-package 'org)

(defun my/straight-update-all ()
  (message "Starting update...")
  (message "Pulling...")
  (straight-pull-all)
  (message "Rebuilding...")
  (straight-rebuild-all)
  (message "Update done!"))

(defalias 'sup 'straight-use-package)

;; organizes folders under emacs directory
(sup 'no-littering)
(require 'no-littering)

(sup 'use-package)

(defalias 'use 'use-package)

(setq straight-use-package-by-default t)

(provide 'core-packages)
