;; get doom emacs theme pack!


;; keep-sorted start

(blink-cursor-mode -1)
(column-number-mode t)
(fringe-mode -1)
(fset 'yes-or-no-p 'y-or-n-p) ;; enable y/n answers
(line-number-mode t)
(menu-bar-mode -1)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(scroll-bar-mode -1)
(setq inhibit-startup-screen t)
(setq ring-bell-function 'ignore)
(setq scroll-margin 0
      scroll-conservatively 100000
      scroll-preserve-screen-position 1)
(setq use-dialog-box nil)
(size-indication-mode t)
(tool-bar-mode -1)
;; keep-sorted end

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

;; Global font ownership lives here; Org-only typography stays in `mod-org.el`.
(defun handle-fonts ()
  (straight-use-package 'nerd-icons)

  (when (member "Iosevka Nerd Font" (font-family-list))
    (set-face-attribute 'default nil :font "Iosevka Nerd Font" :height 216)
    (set-face-attribute 'fixed-pitch nil :family "Iosevka Nerd Font"))

  (when (member "Noto Serif" (font-family-list))
    (set-face-attribute 'variable-pitch nil :family "Noto Serif" :height 1.18)))


(defun handle-theme ()
  (sup 'doom-themes)
  (sup 'kaolin-themes)
  (load-theme 'kaolin-dark t))

(defun handle-modeline ()
  (straight-use-package 'doom-modeline)
  (doom-modeline-mode t)
  ;; keep-sorted start
  (setq doom-modeline-buffer-modification-icon t)
  (setq doom-modeline-buffer-name t)
  (setq doom-modeline-buffer-state-icon t)
  (setq doom-modeline-height 25)
  (setq doom-modeline-hud nil)
  (setq doom-modeline-icon t)
  (setq doom-modeline-lsp-icon t)
  (setq doom-modeline-major-mode-color-icon t)
  (setq doom-modeline-major-mode-icon t)
  (setq doom-modeline-project-detection 'auto)
  (setq doom-modeline-support-imenu t)
  (setq doom-modeline-time-analogue-clock t)
  (setq doom-modeline-time-clock-size 0.7)
  (setq doom-modeline-time-icon t)
  (setq doom-modeline-time-live-icon t)
  (setq doom-modeline-unicode-number t))
  ;; keep-sorted end

;; better help buffer
(defun handle-helpful ()
  (straight-use-package 'helpful)
  ;; keep-sorted start
  (global-set-key (kbd "C-c h f") #'helpful-callable)
  (global-set-key (kbd "C-c h h") #'helpful-at-point)
  (global-set-key (kbd "C-c h k") #'helpful-key)
  (global-set-key (kbd "C-c h v") #'helpful-variable)
  (global-set-key (kbd "C-c h x") #'helpful-command))
  ;; keep-sorted end

(defun handle-links ()
  (use hyperbole
    :init
    (require 'hyperbole)
    (hyperb:init-menubar)))


;; indent guides
(defun handle-indents ()
  (straight-use-package 'highlight-indent-guides)
  (add-hook 'prog-mode-hook 'highlight-indent-guides-mode))

(defun handle-scroll ()
  (sup 'beacon)
  (beacon-mode 1)
  (pixel-scroll-precision-mode t))


;; keep-sorted start
(handle-fonts)
(handle-helpful)
(handle-indents)
(handle-links)
(handle-modeline)
(handle-scroll)
(handle-theme)
;; keep-sorted end

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
