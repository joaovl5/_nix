;; get doom emacs theme pack!


(fringe-mode -1)
(menu-bar-mode -1)
(tool-bar-mode -1)
(blink-cursor-mode -1)
(line-number-mode t)
(column-number-mode t)
(size-indication-mode t)
(setq use-dialog-box nil)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(menu-bar-lines . 0) default-frame-alist)
(scroll-bar-mode -1)

;; enable y/n answers
(fset 'yes-or-no-p 'y-or-n-p)

(setq ring-bell-function 'ignore)
(setq inhibit-startup-screen t)
(setq scroll-margin 0
      scroll-conservatively 100000
      scroll-preserve-screen-position 1)

;; handle margins
(setq-default
  top-margin-width 2
  bottom-margin-height 2
  left-margin-width 2
  right-margin-width 2)
(set-window-buffer nil (current-buffer))

;; show line numbers at the beginning of each line
;; there's a built-in linum-mode, but we're using
;; display-line-numbers-mode or nlinum-mode,
;; as it's supposedly faster
(if (fboundp 'global-display-line-numbers-mode)
    (global-display-line-numbers-mode)
  (global-nlinum-mode t))


;; more useful frame title, that show either a file or a
;; buffer name (if the buffer isn't visiting a file)
(setq frame-title-format
      '("" invocation-name " @ " username " - " (:eval (if (buffer-file-name))
                                                       (abbreviate-file-name (buffer-file-name))
                                                       "%b")))

(defun handle-fonts ()
  (straight-use-package 'nerd-icons))
  ; (nerd-icons-font-family "Iosevka Nerd Font")
  ; (add-to-list 'default-frame-alist
  ;              '(font . "Iosevka Nerd Font-15")
  ;              '(undecorated . t))
  ;
  ; (set-face-attribute 'default nil :family "Iosevka Nerd Font" :height 140 :width 'expanded)
  ; (set-face-attribute 'fixed-pitch nil :family "Iosevka Nerd Font")
  ; (set-face-attribute 'variable-pitch nil :family "Iosevka Nerd Font"))


(defun handle-theme ()
  (straight-use-package 'doom-themes)
  (load-theme 'doom-one t))

(defun handle-modeline ()
  (straight-use-package 'doom-modeline)
  (doom-modeline-mode t)
  (setq doom-modeline-support-imenu t)
  (setq doom-modeline-height 25)
  (setq doom-modeline-hud nil)
  (setq doom-modeline-project-detection 'auto)
  (setq doom-modeline-icon t)
  (setq doom-modeline-major-mode-icon t)
  (setq doom-modeline-major-mode-color-icon t)
  (setq doom-modeline-buffer-state-icon t)
  (setq doom-modeline-buffer-modification-icon t)
  (setq doom-modeline-lsp-icon t)
  (setq doom-modeline-time-icon t)
  (setq doom-modeline-time-live-icon t)
  (setq doom-modeline-time-analogue-clock t)
  (setq doom-modeline-time-clock-size 0.7)
  (setq doom-modeline-unicode-number t)
  (setq doom-modeline-buffer-name t))

;; better help buffer
(defun handle-helpful ()
  (straight-use-package 'helpful)
  (global-set-key (kbd "C-c h f") #'helpful-callable)
  (global-set-key (kbd "C-c h v") #'helpful-variable)
  (global-set-key (kbd "C-c h k") #'helpful-key)
  (global-set-key (kbd "C-c h x") #'helpful-command)
  (global-set-key (kbd "C-c h h") #'helpful-at-point))

(defun handle-links ()
  (use hyperbole
    :ensure t
    :init
    (require 'hyperbole)
    (hyperb:init-menubar))
  )

;; indent guides
(defun handle-indents ()
  (straight-use-package 'highlight-indent-guides)
  (add-hook 'prog-mode-hook 'highlight-indent-guides-mode))

(defun handle-scroll ()
  (sup 'beacon)
  (beacon-mode 1)
  (pixel-scroll-precision-mode t))


(handle-fonts)
(handle-theme)
(handle-modeline)
(handle-helpful)
(handle-indents)
(handle-scroll)
(handle-links)

;; NOTE(@lerax): dom 01 jun 2025 12:42:24
;; helm-descbinds became incompatible with which-key-mode ins 202402XX version
;; Using prelude, calling which-key-mode as hook in
;; server-after-make-frame-hook crash terminal daemoned session
;; this function prevents to this happen
(defun prelude-safe-which-key-mode ()
  (condition-case err
      (which-key-mode +1)
    (error
     (let ((error-message (cadr err)))
       (with-temp-message "" ;; don't print to minibuffer
         (message "[Prelude] bypass error: %s" error-message))))))

;; show available keybindings after you start typing
;; add to hook when running as a daemon as a workaround for a
;; which-key bug
;; https://github.com/justbur/emacs-which-key/issues/306
(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'prelude-safe-which-key-mode)
  (prelude-safe-which-key-mode))

(provide 'core-ui)
