;; mod-org.el --- Org defaults and behavior  -*- lexical-binding: t; -*-

;;; Commentary:
;; org-mode looks, and general config

;;; Code:

(require 'seq)
(declare-function org-download-clipboard "org-download")
(declare-function evil-ret "evil-commands")
(setq
;; keep-sorted start
  org-adapt-indentation t
  org-agenda-tags-column 0
  org-auto-align-tags nil
  org-catch-invisible-edits 'show-and-error
  org-edit-src-content-indentation 0
  org-ellipsis " · "
  org-hide-emphasis-markers t
  org-hide-leading-stars t
  org-insert-heading-respect-content t
  org-log-done t
  org-pretty-entities t
  org-return-follows-link t
  org-special-ctrl-a/e t
  org-src-fontify-natively t
  org-src-tab-acts-natively t
  org-tags-column -80)
;; keep-sorted end

;; Org face setup

(defface my/org-code-face
  '((t (:inherit fixed-pitch)))
  "Org code-like content face.")

;; Single future Org code-font swap point.

(defface my/org-serif-face
  '((t (:inherit variable-pitch)))
  "Org serif heading face.")

(defconst my/org-heading-families
  '("Anonymous Pro" "Liberation Serif")
  "Preferred families for Org headings.")

(defconst my/org-heading-heights
  '((org-level-1 . 1.12)
    (org-level-2 . 1.09)
    (org-level-3 . 1.07)
    (org-level-4 . 1.05)
    (org-level-5 . 1.035)
    (org-level-6 . 1.025)
    (org-level-7 . 1.015)
    (org-level-8 . 1.01))
  "Restrained heading heights for Org headings.")

(defconst my/org-code-faces
  '(org-block
    org-block-begin-line
    org-block-end-line
    org-code
    org-verbatim
    org-table
    org-formula
    org-checkbox)
  "Org faces that should follow `my/org-code-face'.")

(defun my/org-apply-serif-face ()
  (let ((serif-family
         (seq-find (lambda (family)
                     (member family (font-family-list)))
                   my/org-heading-families)))
    (if serif-family
        (set-face-attribute 'my/org-serif-face nil :family serif-family)
      (set-face-attribute 'my/org-serif-face nil :family "serif"))))

(defun my/org-apply-heading-faces ()
  (my/org-apply-serif-face)
  (dolist (face my/org-heading-heights)
    (set-face-attribute (car face) nil
                        :inherit '(my/org-serif-face regular)
                        :weight 'regular
                        :height (cdr face)))
  (set-face-attribute 'org-document-title nil
                      :inherit '(my/org-serif-face regular)
                      :weight 'regular
                      :height 1.32))

(defun my/org-apply-code-faces ()
  (dolist (face my/org-code-faces)
    (set-face-attribute face nil :inherit 'my/org-code-face))
  (set-face-attribute 'org-block-begin-line nil
                      :inherit '(org-meta-line my/org-code-face))
  (set-face-attribute 'org-block-end-line nil
                      :inherit '(org-meta-line my/org-code-face))
  (set-face-attribute 'org-indent nil :inherit '(org-hide fixed-pitch)))

(defun my/org-setup-faces ()
  (my/org-apply-heading-faces)
  (my/org-apply-code-faces))

(defun my/org-refresh-theme-derived-faces (&rest _)
  (when (featurep 'org)
    (my/org-setup-faces)))

(defun my/org-ensure-theme-refresh-hooks ()
  (unless (advice-member-p #'my/org-refresh-theme-derived-faces 'enable-theme)
    (advice-add 'enable-theme :after #'my/org-refresh-theme-derived-faces))
  (unless (advice-member-p #'my/org-refresh-theme-derived-faces 'load-theme)
    (advice-add 'load-theme :after #'my/org-refresh-theme-derived-faces)))

;; Commands

(defun my/org-return-dwim ()
  "Insert a new list item or perform a regular Org return."
  (interactive)
  (if (and (not (org-at-table-p))
           (org-in-item-p))
      (org-insert-item (org-at-item-checkbox-p))
    (call-interactively #'org-return)))

(defun my/org-open-link-or-evil-ret ()
  "Open the Org link at point or preserve Evil's normal Return behavior."
  (interactive)
  (if (org-in-regexp org-link-any-re)
      (org-open-at-point)
    (call-interactively #'evil-ret)))

(defun my/org-shift-return-dwim ()
  "Continue a list item or preserve the standard Org Shift-Return behavior."
  (interactive)
  (if (and (not (org-at-table-p))
           (org-in-item-p))
      (call-interactively #'org-return)
    (call-interactively #'org-table-copy-down)))

(defun my/org-clipboard-has-image-p ()
  "Return non-nil when the Wayland clipboard contains an image."
  (let ((wl_paste (executable-find "wl-paste")))
    (and wl_paste
         (seq-some
          (lambda (mime_type)
            (string-prefix-p "image/" mime_type))
          (ignore-errors
            (process-lines wl_paste "--list-types"))))))

(defun my/org-paste-clipboard-dwim ()
  "Insert a clipboard image with Org Download or yank text."
  (interactive)
  (if (my/org-clipboard-has-image-p)
      (org-download-clipboard)
    (call-interactively #'yank)))

;; Hooks

(defun my/org-mode-setup ()
  (visual-line-mode))

;; Package configuration

(sup 'org-modern)
(with-eval-after-load 'org
  ;; `org-modern` keeps structural polish and ordinary end-of-line tags.
  (setq org-modern-priority nil
        org-modern-progress nil
        org-modern-timestamp nil
        org-modern-todo nil
        org-modern-tag t)
  (global-org-modern-mode))

(use org
     :custom
     (org-startup-folded nil)
     (org-directory "~/org")
     (org-default-notes-file "~/org/agenda.org")
     (org-agenda-files '("~/org/agenda.org"))
     :bind (("C-c o a" . org-agenda)
            ("C-c o c c" . org-capture)
            ("C-c o l y" . org-store-link)
            ("C-c o l p" . org-insert-link)
            ("C-c o r" . org-refile)
            ("C-c o R" . org-archive-subtree)
            ("C-c o t i" . org-clock-in)
            ("C-c o t o" . org-clock-out)
            :map org-mode-map
            ("M-h" . nil)
            ("M-j" . nil)
            ("M-k" . nil)
            ("M-l" . nil)
            ("M-v" . my/org-paste-clipboard-dwim)
            ("M-RET" . org-open-at-point))
     :config
     (evil-define-key 'normal org-mode-map
       (kbd "RET") #'my/org-open-link-or-evil-ret)
     (evil-define-key 'insert org-mode-map
       (kbd "RET") #'my/org-return-dwim
       (kbd "<S-return>") #'my/org-shift-return-dwim)
     (require 'org-indent)
     (my/org-ensure-theme-refresh-hooks)
     (my/org-setup-faces))

(use org-roam
     ; TODO: move to specialized (use-builtin) later
     :straight nil
     :ensure nil
     :commands (org-roam-alias-add
                org-roam-alias-remove
                org-roam-extract-subtree
                org-roam-node-find
                org-roam-node-insert
                org-roam-node-random
                org-roam-ref-add
                org-roam-ref-find
                org-roam-ref-remove
                org-roam-refile
                org-roam-tag-add
                org-roam-tag-remove)
     :custom
     (org-roam-directory (file-truename "~/org/roam/"))
     :bind (("C-c o d" . org-roam-buffer-toggle)
            ("C-c o f" . org-roam-node-find)
            ("C-c o g" . org-roam-graph)
            ("C-c o i" . org-roam-node-insert)
            ("C-c o c r" . org-roam-capture)
            ("C-c o D" . org-roam-dailies-capture-today))
     :config
     (setq org-roam-node-display-template
           (concat "${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
     (setq org-roam-completion-everywhere t)
     (org-roam-db-autosync-mode)
     (require 'org-roam-protocol))

(use org-download
     :ensure t
     :bind (("C-c o p" . org-download-clipboard))
     :init
     (require 'org-download))

(use org-appear
  :commands (org-appear-mode)
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-hide-emphasis-markers t)
  (setq org-appear-autoemphasis t
        org-appear-autolinks t
        org-appear-autosubmarkers t))

;; Hook registration

(add-hook 'org-mode-hook #'my/org-mode-setup)

(provide 'mod-org)
