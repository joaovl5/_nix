; dired config
(defun handle-dired ()
  (straight-use-package 'dirvish)
  (require 'dirvish)
  (dirvish-override-dired-mode)
  (global-set-key (kbd "C-c e") 'dirvish))

(defun handle-projectile ()
  (straight-use-package 'projectile)
  (projectile-mode t))


(defun handle-helm ()
  (straight-use-package 'helm)
  (straight-use-package 'helm-descbinds)
  (straight-use-package 'helm-projectile)
  (straight-use-package 'helm-org)
  (helm-projectile-on))

(defun handle-minibuf ()
  (use vertico
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
(handle-projectile)
; (handle-helm)
(handle-minibuf)

(provide 'core-views)
