(setq package-enable-at-startup nil)

; performance enhancement for treesitter
(setenv "LSP_USE_PLISTS" "true")
(setq lsp-use-plists t)

;; Disable "file-name-handler-alist" than enable it later for speed.
(defvar startup/file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist startup/file-name-handler-alist)
            (makunbound 'startup/file-name-handler-alist)))

(setq package-quickstart t)

(setq use-package-always-defer t)

(setq
  inhibit-splash-screen t
  inhibit-startup-screen t
  inhibit-startup-message t
  inhibit-startup-buffer-menu t)

(setq
  mode-line-format nil
  make-backup-files nil
  backup-directory-alist '((".*" . "~/.local/share/Trash/files")))

(setq initial-major-mode 'fundamental-mode)

; (custom-set-faces
;  ;; Default font for all text
;  '(default ((t (:family "Roboto Mono" :height 110))))
;  '(fixed-pitch ((t (:family "Roboto Mono" :height 100))))
;
;  ;; Current line number
;  '(line-number-current-line ((t (:foreground "yellow" :inherit line-number))))
;  '(mode-line ((t (:family "Roboto Mono" :weight Bold))))
;
;  ;; Comments italic
;  '(font-lock-function-name-face ((t (:family "Roboto Mono":slant italic))))
;  '(font-lock-variable-name-face ((t (:family "Roboto Mono":weight bold)))))
