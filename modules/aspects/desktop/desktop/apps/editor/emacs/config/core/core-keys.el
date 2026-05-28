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
         '(;; keep-sorted start
           ("$" . end-of-visual-line)
           ("," . meow-inner-of-thing)
           ("." . meow-bounds-of-thing)
           ("0" . meow-expand-0)
           ("1" . meow-expand-1)
           ("2" . meow-expand-2)
           ("3" . meow-expand-3)
           ("4" . meow-expand-4)
           ("5" . meow-expand-5)
           ("6" . meow-expand-6)
           ("7" . meow-expand-7)
           ("8" . meow-expand-8)
           ("9" . meow-expand-9)
           (":" . meow-M-x)
           (";" . meow-reverse)
           ("<escape>" . ignore)
           ("B" . meow-back-symbol)
           ("E" . meow-next-symbol)
           ("H" . meow-left-expand)
           ("J" . meow-next-expand)
           ("K" . meow-prev-expand)
           ("L" . meow-right-expand)
           ("W" . meow-mark-symbol)
           ("[" . meow-beginning-of-thing)
           ("\\ w" . visual-line-mode)
           ("]" . meow-end-of-thing)
           ("_" . my-meow-visual-line-smart-bol)
           ("b" . meow-back-word)
           ("e" . meow-next-word)
           ("h" . meow-left)
           ("j" . meow-next)
           ("k" . meow-prev)
           ("l" . meow-right)
           ("m" . meow-join)
           ("w" . meow-mark-word)
           ("x" . meow-line)
           ("y" . meow-save))))
           ;; keep-sorted end
    (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
    (apply #'meow-motion-define-key shared-binds)
    (meow-leader-define-key
     ;; Use SPC (0-9) for digit arguments.
     ;; keep-sorted start
     '("/" . meow-keypad-describe-key)
     '("0" . meow-digit-argument)
     '("1" . meow-digit-argument)
     '("2" . meow-digit-argument)
     '("3" . meow-digit-argument)
     '("4" . meow-digit-argument)
     '("5" . meow-digit-argument)
     '("6" . meow-digit-argument)
     '("7" . meow-digit-argument)
     '("8" . meow-digit-argument)
     '("9" . meow-digit-argument)
     '("?" . meow-cheatsheet))
    ;; keep-sorted end
    (apply #'meow-normal-define-key
           (append
            shared-binds
            '(;;keep-sorted start
              ("'" . repeat)
              ("-" . negative-argument)
              ("A" . meow-open-below)
              ("D" . meow-backward-delete)
              ("G" . meow-grab)
              ("I" . meow-open-above)
              ("O" . meow-to-block)
              ("Q" . meow-goto-line)
              ("R" . meow-swap-grab)
              ("U" . meow-undo-in-selection)
              ("X" . meow-goto-line)
              ("Y" . meow-sync-grab)
              ("a" . meow-append)
              ("c" . meow-change)
              ("d" . meow-delete)
              ("f" . meow-find)
              ("g" . meow-cancel-selection)
              ("i" . meow-insert)
              ("n" . meow-search)
              ("o" . meow-block)
              ("p" . meow-yank)
              ("q" . meow-quit)
              ("r" . meow-replace)
              ("s" . meow-kill)
              ("t" . meow-till)
              ("u" . meow-undo)
              ("v" . meow-visit)
              ("z" . meow-pop-selection))))))
;; keep-sorted end

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

(defun my-quit-emacs ()
  "Save all buffers and quit Emacs without confirmation."
  (interactive)
  (save-some-buffers t)
  (kill-emacs))

(defun my-scroll-half-down ()
  "Scroll down half a page."
  (interactive)
  (scroll-up (/ (window-height) 2)))

(defun my-scroll-half-up ()
  "Scroll up half a page."
  (interactive)
  (scroll-down (/ (window-height) 2)))


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
(global-set-key (kbd "M-d") 'my-scroll-half-down)
(global-set-key (kbd "M-h") 'windmove-left)
(global-set-key (kbd "M-j") 'windmove-down)
(global-set-key (kbd "M-k") 'windmove-up)
(global-set-key (kbd "M-l") 'windmove-right)
(global-set-key (kbd "M-m") 'view-echo-area-messages)
(global-set-key (kbd "M-s") 'save-buffer)
(global-set-key (kbd "M-u") 'my-scroll-half-up)
;; keep-sorted end



(provide 'core-keys)
