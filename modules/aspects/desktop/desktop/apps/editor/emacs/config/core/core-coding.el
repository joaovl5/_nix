;; -*- lexical-binding: t; -*-
(defun my-elisp-flymake-read-syntax (report-fn &rest _args)
  "Report Emacs Lisp reader errors without evaluating buffer code."
  (save-excursion
    (save-restriction
      (widen)
      (let ((diagnostics nil)
            (source (current-buffer))
            (done nil))
        (goto-char (point-min))
        (condition-case error
            (while (not done)
              (skip-chars-forward " \t\n\r\f")
              (if (eobp)
                  (setq done t)
                (read (current-buffer))))
          (error
           (let* ((beg (max (point-min) (1- (point))))
                  (end (min (point-max) (max (point) (1+ beg)))))
             (push (flymake-make-diagnostic source
                                             beg
                                             end
                                             :error
                                             (error-message-string error))
                   diagnostics))))
        (funcall report-fn (nreverse diagnostics))))))

(defun my-elisp-flymake-setup ()
  "Enable Flymake with a safe reader syntax backend for Elisp buffers."
  (add-hook 'flymake-diagnostic-functions
            #'my-elisp-flymake-read-syntax
            nil
            t)
  (unless (trusted-content-p)
    (remove-hook 'flymake-diagnostic-functions
                 #'elisp-flymake-byte-compile
                 t))
  (flymake-mode 1))

(defun my-elisp-flymake-setup-existing-buffers ()
  "Apply `my-elisp-flymake-setup' to existing Elisp buffers."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'emacs-lisp-mode 'lisp-interaction-mode)
        (my-elisp-flymake-setup)))))

(defun my-flymake-sort-diagnostics-by-severity ()
  "Sort Flymake diagnostics list buffers by severity, errors first."
  (setq-local tabulated-list-sort-key '("Type" . t)))


(defun my-flymake-show-diagnostics ()
  "Show project diagnostics, falling back to current-buffer diagnostics."
  (interactive)
  (when (bound-and-true-p flymake-mode)
    (flymake-start nil t))
  (if (project-current nil)
      (flymake-show-project-diagnostics)
    (flymake-show-buffer-diagnostics)))

(use flymake
  :straight nil
  :ensure nil
  :bind (("C-c x b" . flymake-show-buffer-diagnostics)
         ("C-c x x" . my-flymake-show-diagnostics))
  :hook ((emacs-lisp-mode . my-elisp-flymake-setup)
         (flymake-diagnostics-buffer-mode . my-flymake-sort-diagnostics-by-severity)
         (flymake-project-diagnostics-mode . my-flymake-sort-diagnostics-by-severity)
         (lisp-interaction-mode . my-elisp-flymake-setup))
  :config
  (my-elisp-flymake-setup-existing-buffers))

(use eglot
  :straight nil
  :ensure nil
  :hook ((js-mode . eglot-ensure)
         (js-ts-mode . eglot-ensure)
         (nix-mode . eglot-ensure)
         (nix-ts-mode . eglot-ensure)
         (python-mode . eglot-ensure)
         (python-ts-mode . eglot-ensure)
         (rust-mode . eglot-ensure)
         (rust-ts-mode . eglot-ensure)
         (typescript-mode . eglot-ensure)
         (typescript-ts-mode . eglot-ensure)
         (yaml-mode . eglot-ensure)
         (yaml-ts-mode . eglot-ensure))
  :custom
  (eglot-autoshutdown t))

(defun my-citre-capf-first ()
  "Prefer Citre's tags/global completion when Citre is available."
  (setq-local completion-at-point-functions
              (cons #'citre-completion-at-point
                    (remove #'citre-completion-at-point
                            completion-at-point-functions))))

(defun my-citre-elisp-usable-p ()
  "Return non-nil when Citre should use the built-in Elisp Xref backend."
  (derived-mode-p 'emacs-lisp-mode 'lisp-interaction-mode))

(defun my-citre-register-elisp-backend ()
  "Register built-in Emacs Lisp Xref as a Citre backend."
  (require 'citre-xref-adapter)
  (citre-register-backend
   'elisp
   (citre-xref-backend-to-citre-backend
    'elisp
    #'my-citre-elisp-usable-p
    :symbol-atpt-fn (lambda () (thing-at-point 'symbol t)))))


(use citre
  :ensure t
  :commands (citre-jump
             citre-jump-to-reference
             citre-peek
             citre-peek-abort
             citre-peek-reference
             citre-update-this-tags-file)
  :bind (("C-c c p" . citre-peek)
         ("C-c c r" . citre-peek-reference)
         ("C-c c u" . citre-update-this-tags-file)
         ("C-c g d" . citre-peek)
         ("C-c g r" . citre-peek-reference)
         ("C-c g u" . citre-update-this-tags-file)
         ([remap xref-find-definitions] . citre-jump)
         ([remap xref-find-references] . citre-jump-to-reference))
  :custom
  (citre-auto-enable-citre-mode-backends '(tags global elisp))
  (citre-auto-enable-citre-mode-backends-for-remote '(tags global elisp))
  (citre-ctags-program "universal-ctags")
  (citre-default-create-tags-file-location 'global-cache)
  (citre-edit-ctags-options-manually nil)
  (citre-find-definition-backends '(eglot elisp tags global))
  (citre-find-reference-backends '(eglot elisp global))
  (citre-peek-fill-fringe nil)
  (citre-peek-use-dashes-as-horizontal-border t)
  (citre-readtags-program "readtags")
  :init
  (require 'citre-config)
  :hook
  ((citre-mode . my-citre-capf-first)
   (eglot-managed-mode . citre-mode))
  :config
  (my-citre-register-elisp-backend)
  (define-key citre-peek-keymap (kbd "q") #'citre-peek-abort)
  (define-key citre-peek-keymap (kbd "<escape>") #'citre-peek-abort))

(use devdocs
  :ensure t
  :bind (("C-c c d" . devdocs-search)))

(defun my-eldoc-box-bind-quit ()
  "Bind `q' to close the active eldoc-box child frame."
  (local-set-key (kbd "q") #'eldoc-box-quit-frame))

(use eldoc-box
  :ensure t
  :commands (eldoc-box-help-at-point
             eldoc-box-quit-frame)
  :init
  (setq eldoc-echo-area-use-multiline-p nil)
  :config
  (add-hook 'eldoc-box-buffer-hook #'my-eldoc-box-bind-quit))

;; formatting
(use apheleia
  :ensure t
  :demand t
  :config
  (setf (alist-get 'ruff apheleia-formatters)
        '("ruff" "format" "--silent" "--stdin-filename" filepath "-"))
  (setf (alist-get 'guix-style apheleia-formatters)
        '("guix" "style" "-f" inplace))
  (dolist (mode '(emacs-lisp-mode
                  lisp-interaction-mode
                  lisp-mode
                  common-lisp-mode))
    (setf (alist-get mode apheleia-mode-alist) 'lisp-indent))
  (setf (alist-get 'scheme-mode apheleia-mode-alist) 'guix-style)
  (setf (alist-get 'python-mode apheleia-mode-alist) 'ruff)
  (setf (alist-get 'python-ts-mode apheleia-mode-alist) 'ruff)
  (apheleia-global-mode +1))
(provide 'core-coding)
