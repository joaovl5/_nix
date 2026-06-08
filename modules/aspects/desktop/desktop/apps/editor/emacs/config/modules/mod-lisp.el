;; mod-lisp.el --- Stuff for editing lisp  -*- lexical-binding: t; -*-

;;; Commentary:
;; Several things for editing Lisp code.

;;; Code:

;; Parinfer experiment kept disabled for reference while using the
;; Smartparens/aggressive-indent setup below.
;; (declare-function parinfer-rust--defer-loading "parinfer-rust-helper")
;; (declare-function parinfer-rust-mode "parinfer-rust-mode")
;; (declare-function parinfer-rust-mode-enable "parinfer-rust-mode")
;; (defvar parinfer-rust--previous-options)
;; (defvar parinfer-rust-mode)
(declare-function eldoc-box-help-at-point "eldoc-box")
(declare-function evil-local-set-key "evil-core")

(defconst my-elisp-lexical-binding-header ";; -*- lexical-binding: t; -*-\n\n"
  "Header inserted into new Emacs Lisp files.")

(defun my-elisp-insert-lexical-binding-header ()
  "Insert a lexical-binding header in new empty Emacs Lisp files."
  (when (and buffer-file-name
          (derived-mode-p 'emacs-lisp-mode)
          (= (point-min) (point-max)))
    (insert my-elisp-lexical-binding-header)
    (setq-local lexical-binding t)))

(defun my-geiser-use-hover-doc-key ()
  "Use the global hover documentation command on `K' in Geiser buffers."
  (if (fboundp 'evil-local-set-key)
    (evil-local-set-key 'normal (kbd "K") #'eldoc-box-help-at-point)
    (local-set-key (kbd "K") #'eldoc-box-help-at-point)))

;; (defconst my-parinfer-rust-mode-hooks
;;   '(emacs-lisp-mode-hook
;;     lisp-interaction-mode-hook
;;     lisp-mode-hook
;;     scheme-mode-hook)
;;   "Hooks for Lisp-like buffers where Parinfer should be enabled.")
;;
;; (defun my-parinfer-rust-lisp-buffer-p ()
;;   "Return non-nil when the current buffer is a Lisp-like editing buffer."
;;   (derived-mode-p 'lisp-data-mode 'scheme-mode))
;;
;; (defun my-parinfer-rust-selected-buffer-p ()
;;   "Return non-nil when the current buffer is selected."
;;   (eq (current-buffer) (window-buffer (selected-window))))
;;
;; (defun my-parinfer-rust-initialized-p ()
;;   "Return non-nil when Parinfer internals are ready in this buffer."
;;   (and (bound-and-true-p parinfer-rust-mode)
;;        (boundp 'parinfer-rust--previous-options)
;;        parinfer-rust--previous-options))
;;
;; (defun my-enable-parinfer-rust-mode ()
;;   "Enable and initialize Parinfer in Lisp-like editing buffers."
;;   (when (and (my-parinfer-rust-lisp-buffer-p)
;;              (not (my-parinfer-rust-initialized-p)))
;;     (parinfer-rust-mode 1)
;;     (when (and (my-parinfer-rust-selected-buffer-p)
;;                (fboundp 'parinfer-rust--defer-loading))
;;       (remove-hook 'window-selection-change-functions
;;                    #'parinfer-rust--defer-loading
;;                    t))
;;     (when (and (not (my-parinfer-rust-initialized-p))
;;                (my-parinfer-rust-selected-buffer-p)
;;                (fboundp 'parinfer-rust-mode-enable))
;;       (parinfer-rust-mode-enable))))
;;
;; (defun my-enable-parinfer-rust-mode-in-existing-buffers ()
;;   "Enable Parinfer in existing Lisp-like buffers after config reloads."
;;   (dolist (buffer (buffer-list))
;;     (with-current-buffer buffer
;;       (my-enable-parinfer-rust-mode))))

(add-hook 'emacs-lisp-mode-hook #'my-elisp-insert-lexical-binding-header)

(use smartparens
  :ensure t
  :hook ((prog-mode . smartparens-mode)))

(use aggressive-indent
  :ensure t
  :hook ((emacs-lisp-mode . aggressive-indent-mode)
          (lisp-interaction-mode . aggressive-indent-mode)
          (lisp-mode . aggressive-indent-mode)
          (common-lisp-mode . aggressive-indent-mode)))

(use geiser
  :ensure t
  :hook ((scheme-mode . geiser-mode)
          (geiser-mode . my-geiser-use-hover-doc-key))
  :custom
  (geiser-active-implementations '(guile))
  (geiser-default-implementation 'guile)
  (geiser-mode-auto-p nil)
  (geiser-mode-autodoc-p t))

(use geiser-guile
  :ensure t
  :after geiser)

;; (use parinfer-rust-mode
;;      :straight nil
;;      :demand t
;;      :ensure nil
;;      :commands (parinfer-rust-mode
;;                 parinfer-rust-toggle-disable
;;                 parinfer-rust-toggle-paren-mode)
;;      :bind (("C-c ( w" . parinfer-rust-toggle-paren-mode)
;;             ("C-c ( t" . parinfer-rust-toggle-disable))
;;      :init
;;      (setq parinfer-rust-auto-download t
;;            parinfer-rust-check-before-enable nil
;;            parinfer-rust-disable-troublesome-modes t)
;;      :config
;;      (dolist (hook my-parinfer-rust-mode-hooks)
;;        (add-hook hook #'my-enable-parinfer-rust-mode))
;;      (add-hook 'hack-local-variables-hook #'my-enable-parinfer-rust-mode)
;;      (add-hook 'post-command-hook #'my-enable-parinfer-rust-mode)
;;      (my-enable-parinfer-rust-mode-in-existing-buffers))


(provide 'mod-lisp)
