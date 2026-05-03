; dired config
(defun handle-dired ()
  (straight-use-package 'dirvish)
  (require 'dirvish)
  (dirvish-override-dired-mode)
  (global-set-key (kbd "C-c e") 'dirvish))

(defun handle-projectile ()
  (straight-use-package 'projectile)
  (projectile-mode t))

(defun handle-actions ()
  (use consult
       :ensure t
       :bind (("C-c ." . consult-line)
              ("C-c f h" . consult-history)
              ("C-c f m" . consult-man)
              ("C-c f d" . consult-flymake)
              ("C-c f o" . consult-outline)
              ("C-c f m" . consult-mark)
              ("C-c f M" . consult-global-mark)
              ("C-c /" . consult-ripgrep)
              ("C-c <tab>" . consult-buffer)
              ("C-c <spc>" . consult-find)
              ("C-c f h" . consult-history))
       :hook (completion-list-mode . consult-preview-at-point-mode)
       :custom
       (register-preview-delay 0.1)
       (register-preview-function #'consult-register-format)
       (xref-)))



(defun handle-completions ()
  (use corfu
       :ensure t
       :bind
       (:map corfu-map
             ("M-j" . corfu-next)
             ("M-k" . corfu-previous)
             ("M-d" . corfu-next-page)
             ("M-u" . corfu-previous-page))
       :custom
       (corfu-auto t)
       (corfu-preselect t)
       (corfu-quit-no-match 'separator)
       :init
       (global-corfu-mode)
       :config
       (corfu-popupinfo-mode t))
  (use emacs
       :custom
       (tab-always-indent complete)
       (text-mode-ispell-word-completion nil)))

(defun my-vertico-next-page (&optional n)
  "Forward page in Vertico"
  (interactive "p") ;; prefix args
  (let ((steps (* (or n 1) vertico-count)))
    (dotimes (_ steps)
      (vertico-next))))

(defun my-vertico-previous-page (&optional n)
  "Backward page in Vertico"
  (interactive "p") ;; prefix args
  (let ((steps (* (or n 1) vertico-count)))
    (dotimes (_ steps)
      (vertico-previous))))


(defun handle-minibuf ()
  (use vertico
     :bind
     (:map vertico-map
           ("M-j" . vertico-next)
           ("M-k" . vertico-previous)
           ("M-d" . my-vertico-next-page)
           ("M-u" . my-vertico-previous-page))
     :custom
     (vertico-count 20)
     (vertico-cycle t)
     :init
     (vertico-mode)
     (vertico-multiform-mode))
  (use savehist
       :init
       (savehist-mode))
  (use emacs
       :custom
       (context-menu-mode t)
       (enable-recursive-minibuffers t)
       (read-extended-command-predicate #'command-completion-default-include-p)
       (minibuffer-prompt-proprties
         '(read-only t
           cursor-intangible t
           face minibuffer-prompt)))
  (use orderless
       :custom
       (completion-styles '(orderless basic))
       (completion-category-overrides '((file (styles partial-completion))))
       (completion-category-defaults nil)
       (completion-pcm-leading-wildcard t))
  (use nerd-icons-completion
    :init
    (nerd-icons-completion-mode)
    (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))
  (use marginalia
       :bind (:map minibuffer-local-map
               ("M-RET" . marginalia-cycle))
       :init
       (marginalia-mode))
  (use embark
       :ensure t
       :bind (("M-;" . embark-act)
              ("M-:" . embark-dwim))
       :init
       (setq prefix-help-command #'embark-prefix-help-command)
       :config
       ; (setq embark-indicators
       ;  '(embark-minimal-indicator  ; default is embark-mixed-indicator
       ;    embark-highlight-indicator
       ;    embark-isearch-highlight-indicator))
       (add-to-list 'vertico-multiform-categories '(embark-keybinding grid))
       (add-to-list 'display-buffer-alist
                    '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                      nil
                      (window-parameters (mode-line-format . none)))))
  ; (use embark-consult
  ;      :ensure t)
  (global-set-key (kbd "C-c f b") #'list-bookmarks)
  (global-set-key (kbd "C-c f k") #'embark-bindings)
  (global-set-key (kbd "C-c p p") #'projectile-switch-project)
  (global-set-key (kbd "C-c p f") #'projectile-find-file)
  (global-set-key (kbd "C-c p d") #'projectile-find-dir)
  (global-set-key (kbd "C-c p r") #'projectile-recentf)
  (global-set-key (kbd "C-c p /") #'projectile-rg)
  (global-set-key (kbd "C-c p F") #'projectile-find-file-in-known-projects))



(handle-dired)
(handle-actions)
(handle-projectile)
(handle-completions)
(handle-minibuf)

(provide 'core-views)
