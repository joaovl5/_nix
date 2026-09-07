;; mod-org.el --- Org defaults and behavior  -*- lexical-binding: t; -*-

;;; Commentary:
;; org-mode looks, and general config

;;; Code:

(require 'seq)
(declare-function org-download-clipboard "org-download")
(declare-function evil-ret "evil-commands")
;; format: off
(setq
 ;; keep-sorted start
 org-catch-invisible-edits 'show-and-error
 org-edit-src-content-indentation 0
 org-ellipsis " · "
 org-insert-heading-respect-content t
 org-log-done t
 org-pretty-entities t
 org-return-follows-link t
 org-special-ctrl-a/e t
 org-src-fontify-natively t
 org-src-preserve-indentation nil
 org-src-tab-acts-natively t
 org-startup-indented t
 org-tags-column -80)
;; keep-sorted end
;; format: on

;; Org face setup

(defface my/org-code-face '((t (:inherit fixed-pitch)))
  "Org code-like content face.")

;; Single future Org code-font swap point.

(defface my/org-serif-face '((t (:inherit variable-pitch)))
  "Org serif heading face.")

(defconst my/org-heading-families
  '("Anonymous Pro" "Liberation Serif")
  "Preferred families for Org headings.")

(defconst my/org-heading-heights
  '((org-level-1 . 1.2)
    (org-level-2 . 1.15)
    (org-level-3 . 1.12)
    (org-level-4 . 1.09)
    (org-level-5 . 1.07)
    (org-level-6 . 1.05)
    (org-level-7 . 1.025)
    (org-level-8 . 1.0))
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
         (seq-find
          (lambda (family)
            (member family (font-family-list)))
          my/org-heading-families)))
    (if serif-family
        (set-face-attribute 'my/org-serif-face nil
                            :family serif-family)
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
  (set-face-attribute 'org-indent nil
                      :inherit '(org-hide fixed-pitch)))

(defun my/org-setup-faces ()
  (my/org-apply-heading-faces)
  (my/org-apply-code-faces))

(defun my/org-refresh-theme-derived-faces (&rest _)
  (when (featurep 'org)
    (my/org-setup-faces)))

(defun my/org-ensure-theme-refresh-hooks ()
  (unless (advice-member-p
           #'my/org-refresh-theme-derived-faces 'enable-theme)
    (advice-add
     'enable-theme
     :after #'my/org-refresh-theme-derived-faces))
  (unless (advice-member-p
           #'my/org-refresh-theme-derived-faces 'load-theme)
    (advice-add
     'load-theme
     :after #'my/org-refresh-theme-derived-faces)))

;; Commands

(defun my/org-return-dwim ()
  "Insert a new list item or perform a regular Org return."
  (interactive)
  (if (and (not (org-at-table-p)) (org-in-item-p))
      (org-insert-item (org-at-item-checkbox-p))
    (call-interactively #'org-return)))

(defun my/org-normal-ret-dwim ()
  "Act on the Org thing at point from Evil normal state.
Links open, headings cycle their TODO state, checkbox items toggle,
and anything else keeps Evil's Return behavior."
  (interactive)
  (cond
   ((org-in-regexp org-link-any-re)
    (org-open-at-point))
   ((org-at-heading-p)
    (call-interactively #'org-todo))
   ((org-at-item-checkbox-p)
    (call-interactively #'org-toggle-checkbox))
   (t
    (call-interactively #'evil-ret))))

(defun my/org-shift-return-dwim ()
  "Continue a list item or preserve the standard Org Shift-Return behavior."
  (interactive)
  (if (and (not (org-at-table-p)) (org-in-item-p))
      (call-interactively #'org-return)
    (call-interactively #'org-table-copy-down)))

(defun my/org-clipboard-has-image-p ()
  "Return non-nil when the Wayland clipboard contains an image."
  (let ((wl_paste (executable-find "wl-paste")))
    (and wl_paste
         (seq-some
          (lambda (mime_type) (string-prefix-p "image/" mime_type))
          (ignore-errors
            (process-lines wl_paste "--list-types"))))))

(defun my/org-paste-clipboard-dwim ()
  "Insert a clipboard image with Org Download or yank text."
  (interactive)
  (if (my/org-clipboard-has-image-p)
      (org-download-clipboard)
    (call-interactively #'yank)))

;; Block delimiter reveal

;; `org-appear' only knows about emphasis markers, links, entities and
;; hidden keywords, so it never touches the `#+begin_src' line that
;; `org-modern' hides (org-modern applies an `invisible' text property
;; through font-lock).  Mirror `org-appear' behavior for those lines:
;; drop the property while point is on the delimiter line, and let
;; font-lock put it back when point leaves.

(defconst my/org-block-delimiter-re
  "^[ \t]*#\\+\\(?:begin\\|end\\|BEGIN\\|END\\)_"
  "Regexp matching an Org block delimiter line.")

(defvar-local my/org-block-revealed nil
  "Bounds of the block delimiter line currently revealed at point.")

(defun my/org-block-delimiter-bounds ()
  "Return the bounds of the block delimiter line at point, if any."
  (save-excursion
    (beginning-of-line)
    (when (looking-at my/org-block-delimiter-re)
      (cons (line-beginning-position) (line-end-position)))))

(defun my/org-block-reveal-update ()
  "Reveal the Org block delimiter line at point, hide the previous one."
  (let ((bounds (my/org-block-delimiter-bounds)))
    (unless (equal bounds my/org-block-revealed)
      (when my/org-block-revealed
        (let ((beg (car my/org-block-revealed))
              (end (cdr my/org-block-revealed)))
          (when (and (<= (point-min) beg) (<= end (point-max)))
            (font-lock-flush beg end))))
      (setq my/org-block-revealed bounds)
      (when bounds
        ;; The line may not have been fontified yet (for example after a
        ;; jump into an off-screen block).  Fontify first, then reveal;
        ;; otherwise jit-lock would add org-modern's invisibility after
        ;; this hook and leave the delimiter hidden until point moved.
        (font-lock-ensure (car bounds) (cdr bounds))
        (with-silent-modifications
          (remove-text-properties
           (car bounds) (cdr bounds) '(invisible nil)))))))

(define-minor-mode my/org-block-appear-mode
  "Show the raw `#+begin_'/`#+end_' text of the block line at point."
  :lighter
  nil
  (if my/org-block-appear-mode
      (add-hook 'post-command-hook #'my/org-block-reveal-update nil t)
    (remove-hook 'post-command-hook #'my/org-block-reveal-update t)
    (when my/org-block-revealed
      (font-lock-flush
       (car my/org-block-revealed) (cdr my/org-block-revealed))
      (setq my/org-block-revealed nil))))

;; Hooks

(defun my/org-mode-setup ()
  (visual-line-mode t)
  (auto-fill-mode -1)
  (add-hook 'before-save-hook #'delete-trailing-whitespace nil t)

  ; have line spacing ONLY in real lines and not "visual" lines that
  ; happen during wrap
  (with-silent-modifications
    (save-excursion
      (goto-char (point-min))
      (while (search-forward "\n" nil t)
        (put-text-property (1- (point)) (point) 'line-spacing 0.1)))))

;; Package configuration

(sup 'org-modern)
(with-eval-after-load 'org
  ;; `org-modern` keeps structural polish and ordinary end-of-line tags.
  ;; With `org-indent-mode' on, org-modern drops its fringe block
  ;; bracket and leaves leading stars alone: `org-modern-indent' below
  ;; redraws the brackets, and keeping the stars is what gives nested
  ;; headings their increasing indentation.
  (setq
   org-modern-hide-stars nil
   org-modern-priority t
   org-modern-progress t
   org-modern-timestamp t
   org-modern-todo t
   org-modern-tag t)
  (global-org-modern-mode))

;; Reproduces org-modern's block styling under `org-indent-mode', which
;; org-modern itself disables (it needs the fringe).  Must be added late
;; to `org-mode-hook', hence the depth.
(use
 org-modern-indent
 :straight
 (org-modern-indent
  :type git
  :host github
  :repo "jdtsmith/org-modern-indent")
 :commands (org-modern-indent-mode)
 :after org
 :init (add-hook 'org-mode-hook #'org-modern-indent-mode 90))


(use
 org
 :custom
 (org-startup-folded nil)
 (org-directory "~/org")
 (org-default-notes-file "~/org/agenda.org")
 (org-agenda-files '("~/org/agenda.org"))
 :bind
 (("C-c o a" . org-agenda)
  ("C-c o c c" . org-capture)
  ("C-c o l y" . org-store-link)
  ("C-c o l p" . org-insert-link)
  ("C-c o r" . org-refile)
  ("C-c o R" . org-archive-subtree)
  ("C-c o t i" . org-clock-in)
  ("C-c o t o" . org-clock-out)
  :map
  org-mode-map
  ("M-h" . nil)
  ("M-j" . nil)
  ("M-k" . nil)
  ("M-l" . nil)
  ("M-v" . my/org-paste-clipboard-dwim)
  ("M-RET" . org-open-at-point))
 :config
 (setf (alist-get 'file org-link-frame-setup) #'find-file)
 (evil-define-key
  'normal org-mode-map (kbd "RET") #'my/org-normal-ret-dwim)
 (evil-define-key
  'insert
  org-mode-map
  (kbd "RET")
  #'my/org-return-dwim
  (kbd "<S-return>")
  #'my/org-shift-return-dwim)
 (require 'org-indent)
 ;; `org-tempo' is what turns `<s TAB' (and friends) into block
 ;; expansion; without it only `C-c C-,' inserts templates.
 (require 'org-tempo)
 (dolist (template
          '(("el" . "src emacs-lisp")
            ("json" . "src json")
            ("md" . "src markdown")
            ("nix" . "src nix")
            ("py" . "src python")
            ("sh" . "src sh")
            ("scm" . "src scheme")
            ("ts" . "src typescript")
            ("yaml" . "src yaml")))
   (add-to-list 'org-structure-template-alist template))
 (my/org-ensure-theme-refresh-hooks)
 (my/org-setup-faces))

(use
 org-roam
 ; TODO: move to specialized (use-builtin) later
 :straight nil
 :ensure nil
 :commands
 (org-roam-alias-add
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
 :custom (org-roam-directory (file-truename "~/org/roam/"))
 :bind
 (("C-c o d" . org-roam-buffer-toggle)
  ("C-c o f" . org-roam-node-find)
  ("C-c o i" . org-roam-node-insert)
  ("C-c o c r" . org-roam-capture))
 :config
 (setq org-roam-node-display-template
       (concat
        "${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
 (setq org-roam-completion-everywhere t)
 (org-roam-db-autosync-mode)
 (require 'org-roam-protocol))

(use
 org-roam-dailies
 :straight nil
 :ensure nil
 :commands
 (org-roam-dailies-capture-today
  org-roam-dailies-goto-date
  org-roam-dailies-goto-next-note
  org-roam-dailies-goto-previous-note
  org-roam-dailies-goto-today)
 :bind (("C-c o D" . org-roam-dailies-capture-today)))

(use
 org-roam-graph
 :straight nil
 :ensure nil
 :commands org-roam-graph
 :bind (("C-c o g" . org-roam-graph)))

(use
 org-download
 :ensure t
 :bind (("C-c o p" . org-download-clipboard))
 :init (require 'org-download))

(use
 org-appear
 :commands (org-appear-mode)
 :hook (org-mode . org-appear-mode)
 :config (setq org-hide-emphasis-markers t)
 (setq
  org-appear-autoemphasis t
  org-appear-entities t
  org-appear-autokeywords t
  org-appear-autolinks t
  org-appear-autosubmarkers t))

;; Same idea as `org-appear', for the block delimiter lines org-modern
;; hides.  Defined in this file, see "Block delimiter reveal" above.
(add-hook 'org-mode-hook #'my/org-block-appear-mode)

;; Under evaluation, no key bindings yet: `M-x org-timegrid-week' opens
;; the SVG week calendar built from `org-agenda-files'.
(use
 org-timegrid
 :straight (org-timegrid :type git :host github :repo "Gleek/org-timegrid")
 :commands (org-timegrid-week)
 :custom
 (org-timegrid-org-files 'agenda)
 (org-timegrid-default-zoom 0.7)
 :config (require 'org-timegrid-org))

;; Under evaluation, no key bindings yet: `M-x org-remark-mark' marks a
;; region, `org-remark-open' edits its note.  The tracking mode is what
;; makes existing highlights come back when a file is visited again.
(use
 org-remark
 :straight (org-remark :type git :host github :repo "nobiot/org-remark")
 :commands
 (org-remark-mark
  org-remark-mode
  org-remark-next
  org-remark-open
  org-remark-prev
  org-remark-remove
  org-remark-view)
 :init (org-remark-global-tracking-mode +1))

(use valign :hook (org-mode . valign-mode))

(use org-auto-tangle :hook (org-mode . org-auto-tangle-mode))

;; Hook registration

(add-hook 'org-mode-hook #'my/org-mode-setup)

(provide 'mod-org)
