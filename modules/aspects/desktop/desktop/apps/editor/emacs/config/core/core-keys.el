;; --- window-related plugins  -*- lexical-binding: t; -*-

;; windows resize automatically per golden ratio
;; (straight-use-package
;;   '(golden-ratio :type git :host github :repo "roman/golden-ratio.el"))
;; (require 'golden-ratio)
;; (setq golden-ratio-auto-scale t)
;; (golden-ratio-mode 1)


(declare-function citre-peek-abort "citre")
(declare-function eldoc-box-quit-frame "eldoc-box")
(declare-function my-dired-current-file-directory "core-views")
(declare-function my-dired-project-directory "core-views")
(declare-function org-roam-alias-add "org-roam-node")
(declare-function org-roam-alias-remove "org-roam-node")
(declare-function org-roam-extract-subtree "org-roam-node")
(declare-function org-roam-node-find "org-roam-node")
(declare-function org-roam-node-insert "org-roam-node")
(declare-function org-roam-node-random "org-roam-node")
(declare-function org-roam-ref-add "org-roam-node")
(declare-function org-roam-ref-find "org-roam-node")
(declare-function org-roam-ref-remove "org-roam-node")
(declare-function org-roam-refile "org-roam-node")
(declare-function org-roam-tag-add "org-roam-node")
(declare-function org-roam-tag-remove "org-roam-node")
(declare-function evil-force-normal-state "evil")
(declare-function evil-global-set-key "evil")
(declare-function evil-mode "evil")
(declare-function evil-record-macro "evil")
(declare-function evil-set-initial-state "evil")
(declare-function evil-collection-init "evil-collection")
(declare-function evil-quit "evil-commands")
(declare-function evil-quit-all "evil-commands")
(declare-function evil-switch-to-windows-last-buffer "evil-commands")
(declare-function evil-window-down "evil-commands")
(declare-function evil-window-left "evil-commands")
(declare-function evil-window-right "evil-commands")
(declare-function evil-window-split "evil-commands")
(declare-function evil-window-up "evil-commands")
(declare-function evil-window-vsplit "evil-commands")
(declare-function evil-window-decrease-height "evil-commands")
(declare-function evil-window-decrease-width "evil-commands")
(declare-function evil-window-increase-height "evil-commands")
(declare-function evil-window-increase-width "evil-commands")
(declare-function evil-window-move-far-left "evil-commands")
(declare-function evil-window-move-far-right "evil-commands")
(declare-function evil-window-move-very-bottom "evil-commands")
(declare-function evil-window-move-very-top "evil-commands")
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

(defun my-quit-emacs ()
  "Quit Emacs immediately without saving or prompting."
  (interactive)
  (kill-emacs))

(defun my-evil-quit-all ()
  "Quit all windows without saving or prompting."
  (interactive)
  (evil-quit-all t))

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
      (kbd "C-h")
      #'evil-window-left)
    (ek state
      (kbd "C-j")
      #'evil-window-down)
    (ek state
      (kbd "C-k")
      #'evil-window-up)
    (ek state
      (kbd "C-l")
      #'evil-window-right)
    (ek state
      (kbd "C-u")
      #'my-scroll-half-up)
    (ek state
      (kbd "C-y")
      #'my-scroll-line-up))
  (ek 'normal (kbd "K") #'eldoc-box-help-at-point)
  (ek 'normal (kbd "M-L") #'completion-at-point)
  (ek 'normal (kbd "; h") #'evil-window-move-far-left)
  (ek 'normal (kbd "; j") #'evil-window-move-very-bottom)
  (ek 'normal (kbd "; k") #'evil-window-move-very-top)
  (ek 'normal (kbd "; l") #'evil-window-move-far-right)
  (ek 'normal (kbd "; r") #'my-window-resize-hydra/body)
  (ek 'normal (kbd "SPC |") #'evil-window-vsplit)
  (ek 'normal (kbd "SPC -") #'evil-window-split)
  (ek 'normal (kbd "SPC e") #'my-dired-current-file-directory)
  (ek 'normal (kbd "SPC E") #'my-dired-project-directory)
  (ek 'normal (kbd "SPC SPC") #'consult-fd)
  (ek 'normal (kbd "SPC /") #'consult-ripgrep)
  (ek 'normal (kbd "SPC g d") #'citre-peek)
  (ek 'normal (kbd "SPC g r") #'citre-peek-reference)
  (ek 'normal (kbd "SPC g u") #'citre-update-this-tags-file)
  (ek 'normal (kbd "SPC r r") #'org-roam-node-find)
  (ek 'normal (kbd "SPC r R") #'org-roam-ref-find)
  (ek 'normal (kbd "SPC r a r") #'org-roam-ref-add)
  (ek 'normal (kbd "SPC r a t") #'org-roam-tag-add)
  (ek 'normal (kbd "SPC r a a") #'org-roam-alias-add)
  (ek 'normal (kbd "SPC r x r") #'org-roam-ref-remove)
  (ek 'normal (kbd "SPC r x t") #'org-roam-tag-remove)
  (ek 'normal (kbd "SPC r x a") #'org-roam-alias-remove)
  (ek 'normal (kbd "SPC r n r") #'org-roam-refile)
  (ek 'normal (kbd "SPC r n i") #'org-roam-node-insert)
  (ek 'normal (kbd "SPC r n e") #'org-roam-extract-subtree)
  (ek 'normal (kbd "SPC r n R") #'org-roam-node-random)
  (ek 'normal (kbd "SPC w d") #'evil-quit)
  (ek 'normal (kbd "SPC w D") #'my-evil-quit-all)
  (ek 'normal (kbd "SPC w w") #'evil-switch-to-windows-last-buffer)
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

(use hydra
  :ensure t
  :demand t
  :after evil
  :config
  (defhydra my-window-resize-hydra (:color red :hint nil)
    "
Resize: _h_ width-  _l_ width+  _k_ height-  _j_ height+  _<escape>_ exit
"
    ("h" (evil-window-decrease-width 3))
    ("l" (evil-window-increase-width 3))
    ("k" (evil-window-decrease-height 3))
    ("j" (evil-window-increase-height 3))
    ("<escape>" nil :exit t)
    ("RET" nil :exit t)
    ("q" nil :exit t)))

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
(global-set-key (kbd "C-s") 'save-buffer)
(global-set-key (kbd "C-x C-c") #'my-quit-emacs)
(global-set-key (kbd "M-<tab>") 'other-window)
(global-set-key (kbd "M-c") 'kill-ring-save)
(global-set-key (kbd "M-h") 'windmove-left)
(global-set-key (kbd "M-j") 'windmove-down)
(global-set-key (kbd "M-k") 'windmove-up)
(global-set-key (kbd "M-l") 'windmove-right)
(global-set-key (kbd "M-m") 'view-echo-area-messages)
(global-set-key (kbd "M-v") 'yank)
;; keep-sorted end



(provide 'core-keys)
