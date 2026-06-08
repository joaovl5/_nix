;; get doom emacs theme pack!  -*- lexical-binding: t; -*-


(declare-function posframe-poshandler-frame-bottom-center "posframe")
(declare-function which-key-mode "which-key")
(declare-function which-key-posframe-mode "which-key-posframe")

(defvar which-key-allow-imprecise-window-fit)
(defvar which-key-custom-popup-max-dimensions-function)
(defvar which-key-idle-delay)
(defvar which-key-idle-secondary-delay)
(defvar which-key-max-description-length)
(defvar which-key-max-display-columns)
(defvar which-key-min-display-lines)
(defvar which-key-popup-type)
(defvar which-key-side-window-location)
(defvar which-key-side-window-max-height)
(defvar which-key-side-window-max-width)
(defvar which-key-sort-order)
(defvar which-key-unicode-correction)
(defvar which-key-posframe-border-width)
(defvar which-key-posframe-poshandler)

(defconst my-which-key-popup-height 8
  "Fixed height, in lines, for the which-key popup.")

(defconst my-which-key-popup-max-width 0.82
  "Maximum which-key popup width as a fraction of the frame width.")

(defun my-which-key-popup-max-dimensions (_window-width)
  "Return fixed-height max dimensions for the which-key popup."
  (let* ((frame-width (max 1 (- (frame-width) which-key-unicode-correction)))
         (max-width (round (* frame-width my-which-key-popup-max-width))))
    (cons my-which-key-popup-height
          (max 20 (min frame-width max-width)))))

(defun my-which-key-setup-side-window ()
  "Use a terminal-safe bottom side window for which-key."
  (when (fboundp 'which-key-posframe-mode)
    (which-key-posframe-mode -1))
  (setq which-key-allow-imprecise-window-fit t
        which-key-popup-type 'side-window
        which-key-side-window-location 'bottom
        which-key-side-window-max-height my-which-key-popup-height
        which-key-side-window-max-width my-which-key-popup-max-width))

(defun my-which-key-setup-posframe ()
  "Use a centered graphical posframe for which-key."
  (straight-use-package 'which-key-posframe)
  (require 'which-key-posframe)
  (setq which-key-posframe-border-width 1
        which-key-posframe-poshandler #'posframe-poshandler-frame-bottom-center)
  (which-key-posframe-mode 1)
  (setq which-key-custom-popup-max-dimensions-function
        #'my-which-key-popup-max-dimensions))

(defun my-which-key-setup-style ()
  "Configure which-key sizing, columns, and placement."
  (require 'which-key)
  (setq which-key-idle-delay 0
        which-key-idle-secondary-delay 0
        which-key-max-description-length 35
        which-key-max-display-columns nil
        which-key-min-display-lines my-which-key-popup-height
        which-key-sort-order 'which-key-key-order-alpha)
  (if (and (display-graphic-p)
           (window-system))
      (my-which-key-setup-posframe)
    (my-which-key-setup-side-window)))
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
  (global-set-key (kbd "C-c h x") #'helpful-command)
  (global-set-key (kbd "C-k") #'helpful-at-point))
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
  (use pixel-scroll
       :straight nil
       :ensure nil
       :bind (([remap scroll-up-command] . pixel-scroll-interpolate-down)
              ([remap scroll-down-command] . pixel-scroll-interpolate-up))
       :custom
       (pixel-scroll-precision-interpolate-page t)
       (pixel-scroll-precision-interpolation-total-time 0.25)
       :init
       (pixel-scroll-precision-mode 1))
  (use scroll-on-jump
       :ensure t
       :custom
       (scroll-on-jump-curve 'smooth-out)
       (scroll-on-jump-duration 0.4)
       :config
       (with-eval-after-load 'evil
         (scroll-on-jump-advice-add evil-ex-search-next)
         (scroll-on-jump-advice-add evil-ex-search-previous)
         (scroll-on-jump-advice-add evil-goto-mark)
         (scroll-on-jump-advice-add evil-goto-mark-line)
         (scroll-on-jump-advice-add evil-jump-backward)
         (scroll-on-jump-advice-add evil-jump-forward)
         (scroll-on-jump-advice-add evil-jump-item)
         (scroll-on-jump-with-scroll-advice-add evil-goto-line)
         (scroll-on-jump-with-scroll-advice-add evil-scroll-line-to-bottom)
         (scroll-on-jump-with-scroll-advice-add evil-scroll-line-to-center)
         (scroll-on-jump-with-scroll-advice-add evil-scroll-line-to-top)))
)


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
      (progn
        (my-which-key-setup-style)
        (which-key-mode +1))
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
