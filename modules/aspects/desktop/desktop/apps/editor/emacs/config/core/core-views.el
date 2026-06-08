; dired config  -*- lexical-binding: t; -*-
(require 'project)
(declare-function dirvish-override-dired-mode "dirvish")
(declare-function evil-define-key "evil")

(defun my-dired-open-directory (directory)
  "Open DIRECTORY with plain Dired, bypassing Dirvish's Dired override."
  (let ((dirvish-was-enabled (bound-and-true-p dirvish-override-dired-mode)))
    (unwind-protect
        (progn
          (when (and dirvish-was-enabled
                     (fboundp 'dirvish-override-dired-mode))
            (dirvish-override-dired-mode -1))
          (dired directory))
      (when (and dirvish-was-enabled
                 (fboundp 'dirvish-override-dired-mode))
        (dirvish-override-dired-mode 1)))))

(defun my-dired-current-file-directory ()
  "Open Dired in the directory of the current buffer file."
  (interactive)
  (my-dired-open-directory
   (file-name-as-directory
    (expand-file-name
     (or (and buffer-file-name
              (file-name-directory buffer-file-name))
         default-directory)))))

(defun my-dired-project-directory ()
  "Open Dired in the current project root, falling back to `default-directory'."
  (interactive)
  (my-dired-open-directory
   (file-name-as-directory
    (expand-file-name
     (or (when-let ((project (project-current nil)))
           (project-root project))
         default-directory)))))

(defun handle-dired ()
  (use dired
       :straight nil
       :ensure nil
       :hook (dired-mode . auto-revert-mode)
       :custom
       (dired-listing-switches "-alh --group-directories-first")
       :config
       (with-eval-after-load 'evil
         (evil-define-key 'normal dired-mode-map
           (kbd "h") #'dired-up-directory
           (kbd "l") #'dired-find-file)))
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
       :bind (;; keep-sorted start
              ("C-c ." . consult-line)
              ("C-c /" . consult-ripgrep)
              ("C-c <spc>" . consult-find)
              ("C-c <tab>" . consult-buffer)
              ("C-c f M" . consult-global-mark)
              ("C-c f d" . consult-flymake)
              ("C-c f h" . consult-history)
              ("C-c f m" . consult-man)
              ("C-c f m" . consult-mark)
              ("C-c f o" . consult-outline))
              ;; keep-sorted end
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
             ;; keep-sorted start
             ("M-d" . corfu-next-page)
             ("M-j" . corfu-next)
             ("M-k" . corfu-previous)
             ("M-u" . corfu-previous-page))
             ;; keep-sorted end
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
       (tab-always-indent 'complete)
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
           ;; keep-sorted start
           ("C-d" . my-vertico-next-page)
           ("C-u" . my-vertico-previous-page)
           ("M-j" . vertico-next)
           ("M-k" . vertico-previous))
           ;; keep-sorted end
     :custom
     (vertico-count 10)
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
  ;; keep-sorted start
  (global-set-key (kbd "C-c f b") #'list-bookmarks)
  (global-set-key (kbd "C-c f k") #'embark-bindings)
  (global-set-key (kbd "C-c p /") #'projectile-rg)
  (global-set-key (kbd "C-c p F") #'projectile-find-file-in-known-projects)
  (global-set-key (kbd "C-c p d") #'projectile-find-dir)
  (global-set-key (kbd "C-c p f") #'projectile-find-file)
  (global-set-key (kbd "C-c p p") #'projectile-switch-project)
  (global-set-key (kbd "C-c p r") #'projectile-recentf))
  ;; keep-sorted end



;; keep-sorted start
(handle-actions)
(handle-completions)
(handle-dired)
(handle-minibuf)
(handle-projectile)
;; keep-sorted end

(provide 'core-views)
