;; --- window-related plugins

;; windows resize automatically per golden ratio
(straight-use-package
  '(golden-ratio :type git :host github :repo "roman/golden-ratio.el"))
(require 'golden-ratio)
(setq golden-ratio-auto-scale t)
(golden-ratio-mode 1)


(defun my-meow-visual-line-smart-bol ()
  (interactive)
  (let* ((visual_line_start (save-excursion
                              (beginning-of-visual-line)
                              (point)))
         (visual_line_end (save-excursion
                            (end-of-visual-line)
                            (point)))
         (first_text_point (save-excursion
                             (goto-char visual_line_start)
                             (if (re-search-forward "[^ \t]" visual_line_end t)
                                 (match-beginning 0)
                               visual_line_start))))
    (goto-char (if (= (point) first_text_point)
                   visual_line_start
                 first_text_point))))

(defun meow-setup ()
  (let ((shared-binds
         '(("\\ w" . visual-line-mode)
           ("0" . meow-expand-0)
           ("9" . meow-expand-9)
           ("8" . meow-expand-8)
           ("7" . meow-expand-7)
           ("6" . meow-expand-6)
           ("5" . meow-expand-5)
           ("4" . meow-expand-4)
           ("3" . meow-expand-3)
           ("2" . meow-expand-2)
           ("1" . meow-expand-1)
           (":" . meow-M-x)
           ("$" . end-of-visual-line)
           (";" . meow-reverse)
           ("," . meow-inner-of-thing)
           ("." . meow-bounds-of-thing)
           ("[" . meow-beginning-of-thing)
           ("]" . meow-end-of-thing)
           ("_" . my-meow-visual-line-smart-bol)
           ("b" . meow-back-word)
           ("B" . meow-back-symbol)
           ("e" . meow-next-word)
           ("E" . meow-next-symbol)
           ("h" . meow-left)
           ("H" . meow-left-expand)
           ("j" . meow-next)
           ("J" . meow-next-expand)
           ("k" . meow-prev)
           ("K" . meow-prev-expand)
           ("l" . meow-right)
           ("L" . meow-right-expand)
           ("m" . meow-join)
           ("w" . meow-mark-word)
           ("W" . meow-mark-symbol)
           ("x" . meow-line)
           ("y" . meow-save)
           ("<escape>" . ignore))))
    (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
    (apply #'meow-motion-define-key shared-binds)
    (meow-leader-define-key
     ;; Use SPC (0-9) for digit arguments.
     '("1" . meow-digit-argument)
     '("2" . meow-digit-argument)
     '("3" . meow-digit-argument)
     '("4" . meow-digit-argument)
     '("5" . meow-digit-argument)
     '("6" . meow-digit-argument)
     '("7" . meow-digit-argument)
     '("8" . meow-digit-argument)
     '("9" . meow-digit-argument)
     '("0" . meow-digit-argument)
     '("/" . meow-keypad-describe-key)
     '("?" . meow-cheatsheet))
    (apply #'meow-normal-define-key
           (append
            shared-binds
            '(("-" . negative-argument)
              ("a" . meow-append)
              ("A" . meow-open-below)
              ("c" . meow-change)
              ("d" . meow-delete)
              ("D" . meow-backward-delete)
              ("f" . meow-find)
              ("g" . meow-cancel-selection)
              ("G" . meow-grab)
              ("i" . meow-insert)
              ("I" . meow-open-above)
              ("n" . meow-search)
              ("o" . meow-block)
              ("O" . meow-to-block)
              ("p" . meow-yank)
              ("q" . meow-quit)
              ("Q" . meow-goto-line)
              ("r" . meow-replace)
              ("R" . meow-swap-grab)
              ("s" . meow-kill)
              ("t" . meow-till)
              ("u" . meow-undo)
              ("U" . meow-undo-in-selection)
              ("v" . meow-visit)
              ("X" . meow-goto-line)
              ("Y" . meow-sync-grab)
              ("z" . meow-pop-selection)
              ("'" . repeat))))))


(defun handle-meow ()
  (require 'meow)
  (meow-setup)
  (meow-global-mode 1)
  (setq meow-expand-exclude-mode-list
        (delq 'org-mode meow-expand-exclude-mode-list))
  (add-to-list 'meow-mode-state-list '(vterm-mode . insert))
  (add-to-list 'meow-mode-state-list '(sly-mrepl-mode . insert))
  (add-to-list 'meow-mode-state-list '(inferior-emacs-lisp-mode . insert))
  (add-to-list 'meow-mode-state-list '(eat-mode . insert))
  (add-to-list 'meow-mode-state-list '(erc-mode . insert)))

(use meow
     :ensure t
     :custom
     (meow-use-clipboard t)
     :init (handle-meow))

; (setq windmove-create-window t)

(global-set-key (kbd "M-<tab>") 'other-window)
(global-set-key (kbd "C-c |") 'split-window-right)
(global-set-key (kbd "C-c -") 'split-window-below)
(global-set-key (kbd "M-h") 'windmove-left)
(global-set-key (kbd "M-j") 'windmove-down)
(global-set-key (kbd "M-k") 'windmove-up)
(global-set-key (kbd "M-l") 'windmove-right)
(global-set-key (kbd "M-s") 'save-buffer)
(global-set-key (kbd "<C-up>") (lambda () (interactive) (shrink-window 10)))
(global-set-key (kbd "<C-down>") (lambda () (interactive) (enlarge-window 10)))
(global-set-key (kbd "<C-left>") (lambda () (interactive (shrink-window-horizontally 10))))
(global-set-key (kbd "<C-right>") (lambda () (interactive) (enlarge-window-horizontally 10)))
(global-set-key (kbd "C-c q") 'delete-window)
(defun my-quit-emacs ()
  "Save all buffers and quit Emacs without confirmation."
  (interactive)
  (save-some-buffers t)
  (kill-emacs))
(global-set-key (kbd "C-c Q") #'my-quit-emacs)
(global-set-key (kbd "C-c ;") 'eval-expression)
(global-set-key (kbd "C-l") 'completion-at-point)
(global-set-key (kbd "M-m") 'view-echo-area-messages)

(defun my-scroll-half-down ()
  "Scroll down half a page."
  (interactive)
  (scroll-up (/ (window-height) 2)))

(defun my-scroll-half-up ()
  "Scroll up half a page."
  (interactive)
  (scroll-down (/ (window-height) 2)))

(global-set-key (kbd "M-d") 'my-scroll-half-down)
(global-set-key (kbd "M-u") 'my-scroll-half-up)


;; handle keys

(provide 'core-keys)
