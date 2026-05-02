;; init straight.el
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

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
