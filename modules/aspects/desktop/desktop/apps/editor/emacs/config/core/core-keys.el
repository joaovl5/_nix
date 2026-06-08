;; --- window-related plugins  -*- lexical-binding: t; -*-

;; windows resize automatically per golden ratio
(straight-use-package
  '(golden-ratio :type git :host github :repo "roman/golden-ratio.el"))
(require 'golden-ratio)
(setq golden-ratio-auto-scale t)
(golden-ratio-mode 1)


(declare-function citre-peek-abort "citre")
(declare-function eldoc-box-quit-frame "eldoc-box")
(declare-function my-dired-current-file-directory "core-views")
(declare-function my-dired-project-directory "core-views")
(declare-function evil-force-normal-state "evil")
(declare-function evil-global-set-key "evil")
(declare-function evil-mode "evil")
(declare-function evil-record-macro "evil")
(declare-function evil-set-initial-state "evil")
(declare-function evil-collection-init "evil-collection")
(declare-function pixel-scroll-precision-interpolate "pixel-scroll")
(defvar citre-peek--mode)
(defvar eldoc-box--frame)

(defun my-close-transient-ui ()
  "Close transient overlay/child-frame UI when one is active."
  (cond
    ((and (bound-and-true-p citre-peek--mode)
       (fboundp 'citre-peek-abort))
      (citre-peek-abort)
      t)
    ((and (boundp 'eldoc-box--frame)
       (eq (selected-frame) eldoc-box--frame)
       (fboundp 'eldoc-box-quit-frame))
      (eldoc-box-quit-frame)
      t)
    (t nil)))

(defun my-evil-record-macro-or-close ()
  "Close transient UI before falling back to Evil macro recording."
  (interactive)
  (unless (my-close-transient-ui)
    (call-interactively #'evil-record-macro)))

(defun my-evil-force-normal-state-or-close ()
  "Close transient UI before falling back to Evil normal-state behavior."
  (interactive)
  (unless (my-close-transient-ui)
    (call-interactively #'evil-force-normal-state)))

(defun my-evil-setup ()
  "Configure Evil bindings and initial states."
  (defalias 'ek 'evil-global-set-key)
  (dolist (state '(normal motion visual))
    (ek state
      (kbd "<escape>")
      #'my-evil-force-normal-state-or-close))
  (dolist (state '(normal motion visual))
    (ek state
      (kbd "C-b")
      #'my-scroll-page-up)
    (ek state
      (kbd "C-d")
      #'my-scroll-half-down)
    (ek state
      (kbd "C-e")
      #'my-scroll-line-down)
    (ek state
      (kbd "C-f")
      #'my-scroll-page-down)
    (ek state
      (kbd "C-u")
      #'my-scroll-half-up)
    (ek state
      (kbd "C-y")
      #'my-scroll-line-up))
  (ek 'normal (kbd "K") #'eldoc-box-help-at-point)
  (ek 'normal (kbd "M-L") #'completion-at-point)
  (ek 'normal (kbd "SPC e") #'my-dired-current-file-directory)
  (ek 'normal (kbd "SPC E") #'my-dired-project-directory)
  (ek 'normal (kbd "SPC SPC") #'consult-fd)
  (ek 'normal (kbd "SPC /") #'consult-ripgrep)
  (ek 'normal (kbd "SPC g d") #'citre-peek)
  (ek 'normal (kbd "SPC g r") #'citre-peek-reference)
  (ek 'normal (kbd "SPC g u") #'citre-update-this-tags-file)
  (ek 'normal (kbd "SPC x x") #'my-flymake-show-diagnostics)
  (ek 'normal (kbd "g d") #'citre-peek)
  (ek 'normal (kbd "g r") #'citre-peek-reference)
  (ek 'normal (kbd "q") #'my-evil-record-macro-or-close)
  (evil-set-initial-state 'vterm-mode 'emacs)
  (evil-set-initial-state 'sly-mrepl-mode 'emacs)
  (evil-set-initial-state 'inferior-emacs-lisp-mode 'emacs)
  (evil-set-initial-state 'eat-mode 'emacs)
  (evil-set-initial-state 'erc-mode 'emacs))

(use evil
  :ensure t
  :demand t
  :init
  (setq evil-respect-visual-line-mode t)
  (setq evil-undo-system 'undo-redo)
  (setq evil-want-C-u-scroll t)
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  :config
  (my-evil-setup)
  (evil-mode 1))

(use evil-collection
  :ensure t
  :demand t
  :after evil
  :config
  (evil-collection-init))


(defun my-scroll--count (&optional count)
  "Return COUNT as a positive number, defaulting to 1."
  (max 1 (prefix-numeric-value (or count 1))))

(defun my-scroll--line-pixels (&optional count)
  "Return pixel distance for COUNT lines."
  (* (my-scroll--count count)
    (frame-char-height)))

(defun my-scroll--window-pixels (&optional count)
  "Return pixel distance for COUNT windows."
  (* (my-scroll--count count)
    (window-text-height nil t)))

(defun my-scroll--half-window-pixels (&optional count)
  "Return pixel distance for COUNT lines, or half the window."
  (if count
    (my-scroll--line-pixels count)
    (/ (window-text-height nil t) 2)))

(defun my-scroll--smooth-pixels (delta)
  "Scroll the selected window by DELTA pixels with animation."
  (unless (fboundp 'pixel-scroll-precision-interpolate)
    (require 'pixel-scroll nil t))
  (condition-case error
    (if (fboundp 'pixel-scroll-precision-interpolate)
      (pixel-scroll-precision-interpolate delta nil 1)
      (if (< delta 0)
        (scroll-up (/ (window-body-height) 2))
        (scroll-down (/ (window-body-height) 2))))
    (beginning-of-buffer
      (message "%s" (error-message-string error)))
    (end-of-buffer
      (message "%s" (error-message-string error)))))

(defun my-scroll-half-down (&optional count)
  "Smoothly scroll down by COUNT lines, or half a window."
  (interactive "P")
  (my-scroll--smooth-pixels (- (my-scroll--half-window-pixels count))))

(defun my-scroll-half-up (&optional count)
  "Smoothly scroll up by COUNT lines, or half a window."
  (interactive "P")
  (my-scroll--smooth-pixels (my-scroll--half-window-pixels count)))

(defun my-scroll-line-down (&optional count)
  "Smoothly scroll down by COUNT lines."
  (interactive "P")
  (my-scroll--smooth-pixels (- (my-scroll--line-pixels count))))

(defun my-scroll-line-up (&optional count)
  "Smoothly scroll up by COUNT lines."
  (interactive "P")
  (my-scroll--smooth-pixels (my-scroll--line-pixels count)))

(defun my-scroll-page-down (&optional count)
  "Smoothly scroll down by COUNT windows."
  (interactive "P")
  (my-scroll--smooth-pixels (- (my-scroll--window-pixels count))))

(defun my-scroll-page-up (&optional count)
  "Smoothly scroll up by COUNT windows."
  (interactive "P")
  (my-scroll--smooth-pixels (my-scroll--window-pixels count)))

(put 'my-scroll-half-down 'scroll-command t)
(put 'my-scroll-half-up 'scroll-command t)
(put 'my-scroll-line-down 'scroll-command t)
(put 'my-scroll-line-up 'scroll-command t)
(put 'my-scroll-page-down 'scroll-command t)
(put 'my-scroll-page-up 'scroll-command t)


;; keep-sorted start
(global-set-key (kbd "<C-down>") (lambda () (interactive) (enlarge-window 10)))
(global-set-key (kbd "<C-left>") (lambda () (interactive (shrink-window-horizontally 10))))
(global-set-key (kbd "<C-right>") (lambda () (interactive) (enlarge-window-horizontally 10)))
(global-set-key (kbd "<C-up>") (lambda () (interactive) (shrink-window 10)))
(global-set-key (kbd "C-c -") 'split-window-below)
(global-set-key (kbd "C-c ;") 'eval-expression)
(global-set-key (kbd "C-c Q") #'my-quit-emacs)
(global-set-key (kbd "C-c q") 'delete-window)
(global-set-key (kbd "C-c |") 'split-window-right)
(global-set-key (kbd "C-l") 'completion-at-point)
(global-set-key (kbd "M-<tab>") 'other-window)
(global-set-key (kbd "M-h") 'windmove-left)
(global-set-key (kbd "M-j") 'windmove-down)
(global-set-key (kbd "M-k") 'windmove-up)
(global-set-key (kbd "M-l") 'windmove-right)
(global-set-key (kbd "M-m") 'view-echo-area-messages)
(global-set-key (kbd "M-s") 'save-buffer)
;; keep-sorted end



(provide 'core-keys)
