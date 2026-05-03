;; mod-org.el --- Org defaults and behavior  -*- lexical-binding: t; -*-

;;; Commentary:
;; org-mode looks, and general config

;;; Code:

(require 'cl-lib)
(require 'color)
(require 'seq)

(setq
 org-auto-align-tags nil
 org-catch-invisible-edits 'show-and-error
 org-special-ctrl-a/e t
 org-insert-heading-respect-content t
 org-hide-emphasis-markers t
 org-pretty-entities t
 org-agenda-tags-column 0
 org-ellipsis " · "
 org-adapt-indentation t
 org-hide-leading-stars t
 org-log-done t
 org-tags-column -80
 org-src-fontify-natively t
 org-src-tab-acts-natively t
 org-edit-src-content-indentation 0)

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
  (my/org-apply-code-faces)
  (my/org-apply-badge-faces))

;; Badge helpers

(defface my/org-badge-priority-face
  '((t (:inherit org-priority)))
  "Theme-derived face for priority badges.")

(defface my/org-badge-progress-face
  '((t (:inherit org-todo)))
  "Theme-derived face for in-progress badges.")

(defface my/org-badge-progress-done-face
  '((t (:inherit org-done)))
  "Theme-derived face for completed progress badges.")

(defface my/org-badge-date-face
  '((t (:inherit org-date)))
  "Theme-derived face for date badges.")

(defface my/org-badge-muted-face
  '((t (:inherit shadow)))
  "Theme-derived face for muted metadata badges.")

(defun my/org-face-color (face attribute &optional fallback-face fallback)
  (let ((value (face-attribute face attribute nil t)))
    (cond
     ((and (stringp value)
           (not (member value '("unspecified" "unspecified-fg" "unspecified-bg"))))
      value)
     (fallback-face (my/org-face-color fallback-face attribute nil fallback))
     (t fallback))))

(defun my/org-blend-with-default-background (color alpha)
  (let* ((background (my/org-face-color 'default :background nil "#000000"))
         (color-rgb (color-name-to-rgb color))
         (background-rgb (color-name-to-rgb background)))
    (apply #'color-rgb-to-hex
           (cl-mapcar (lambda (component base)
                        (+ (* alpha component) (* (- 1 alpha) base)))
                      color-rgb
                      background-rgb))))

(defun my/org-apply-badge-face (target source &optional fallback-source)
  (let* ((foreground (my/org-face-color source :foreground fallback-source
                                        (my/org-face-color 'default :foreground nil "#ffffff")))
         (background (or (my/org-face-color source :background fallback-source nil)
                         (my/org-blend-with-default-background foreground 0.18)))
         (border (my/org-blend-with-default-background foreground 0.32)))
    (set-face-attribute target nil
                        :inherit nil
                        :foreground foreground
                        :background background
                        :weight 'semibold
                        :box `(:line-width 1 :color ,border :style nil))))

(defun my/org-apply-badge-faces ()
  (my/org-apply-badge-face 'my/org-badge-priority-face 'org-priority 'warning)
  (my/org-apply-badge-face 'my/org-badge-progress-face 'org-todo)
  (my/org-apply-badge-face 'my/org-badge-progress-done-face 'org-done 'success)
  (my/org-apply-badge-face 'my/org-badge-date-face 'org-date)
  (my/org-apply-badge-face 'my/org-badge-muted-face 'shadow))

(defun my/org-refresh-theme-derived-faces (&rest _)
  (when (featurep 'org)
    (my/org-setup-faces)))

(defun my/org-ensure-theme-refresh-hooks ()
  (unless (advice-member-p #'my/org-refresh-theme-derived-faces 'enable-theme)
    (advice-add 'enable-theme :after #'my/org-refresh-theme-derived-faces))
  (unless (advice-member-p #'my/org-refresh-theme-derived-faces 'load-theme)
    (advice-add 'load-theme :after #'my/org-refresh-theme-derived-faces)))

(defun my/org-svg-tag (tag face &rest properties)
  (apply #'svg-tag-make tag :face face :margin 0 properties))

(defconst my/org-meta-icon-badge-style
  '(:collection "material"
    :height 0.8
    :scale 0.72
    :padding 0.15
    :radius 2
    :stroke 0)
  "Compact style for Org metadata icon badges.")

(defun my/org-meta-icon-badge (icon face &optional fallback)
  (or (ignore-errors
        (apply #'svg-lib-icon icon face my/org-meta-icon-badge-style))
      (my/org-svg-tag (or fallback "?") face
                      :font-size 14
                      :height 0.9
                      :padding 0.8
                      :radius 2
                      :stroke 0)))

(defun my/org-svg-face-foreground (face)
  (my/org-face-color face :foreground nil
                     (my/org-face-color 'default :foreground nil "#ffffff")))

(defun my/org-svg-face-background (face)
  (or (my/org-face-color face :background nil nil)
      (my/org-blend-with-default-background (my/org-svg-face-foreground face) 0.18)))

(defun my/org-progress-face (progress)
  (if (>= progress 1.0)
      'my/org-badge-progress-done-face
    'my/org-badge-progress-face))

(defun my/org-clamp-progress (progress)
  (max 0.0 (min 1.0 progress)))

(defconst my/org-timestamp-date-re
  "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}"
  "Regexp fragment matching the date portion of an Org timestamp.")

(defconst my/org-timestamp-time-re
  "[0-9]\\{2\\}:[0-9]\\{2\\}"
  "Regexp fragment matching the time portion of an Org timestamp.")

(defconst my/org-timestamp-day-re
  "[A-Za-z]\\{3\\}"
  "Regexp fragment matching the weekday portion of an Org timestamp.")

(defconst my/org-timestamp-day-only-re
  my/org-timestamp-day-re
  "Regexp fragment matching a weekday-only timestamp suffix.")

(defconst my/org-timestamp-timed-suffix-re
  (format "\\(?:%s %s\\|%s\\)"
          my/org-timestamp-day-re
          my/org-timestamp-time-re
          my/org-timestamp-time-re)
  "Regexp fragment matching a timestamp suffix that includes a time.")

(defconst my/org-timestamp-suffix-re
  (format "\\(?:%s %s\\|%s\\|%s\\)"
          my/org-timestamp-day-re
          my/org-timestamp-time-re
          my/org-timestamp-day-re
          my/org-timestamp-time-re)
  "Regexp fragment matching the optional non-date part of an Org timestamp.")

(defconst my/org-active-date-regexp
  (format "\\(<%s>\\)" my/org-timestamp-date-re)
  "Regexp matching an active Org date without a suffix.")

(defconst my/org-active-date-prefix-regexp
  (format "\\(<%s \\)%s>" my/org-timestamp-date-re my/org-timestamp-timed-suffix-re)
  "Regexp matching the left half of an active Org timestamp.")

(defconst my/org-active-date-prefix-day-only-regexp
  (format "\\(<%s \\)%s>" my/org-timestamp-date-re my/org-timestamp-day-only-re)
  "Regexp matching the left half of an active all-day Org timestamp.")

(defconst my/org-active-date-suffix-regexp
  (format "<%s \\(%s>\\)" my/org-timestamp-date-re my/org-timestamp-timed-suffix-re)
  "Regexp matching the right half of an active Org timestamp.")

(defconst my/org-active-date-suffix-day-only-regexp
  (format "<%s \\(%s>\\)" my/org-timestamp-date-re my/org-timestamp-day-only-re)
  "Regexp matching the right half of an active all-day Org timestamp.")

(defconst my/org-inactive-date-regexp
  (format "\\(\\[%s\\]\\)" my/org-timestamp-date-re)
  "Regexp matching an inactive Org date without a suffix.")

(defconst my/org-inactive-date-prefix-regexp
  (format "\\(\\[%s \\)%s\\]" my/org-timestamp-date-re my/org-timestamp-timed-suffix-re)
  "Regexp matching the left half of an inactive Org timestamp.")

(defconst my/org-inactive-date-prefix-day-only-regexp
  (format "\\(\\[%s \\)%s\\]" my/org-timestamp-date-re my/org-timestamp-day-only-re)
  "Regexp matching the left half of an inactive all-day Org timestamp.")

(defconst my/org-inactive-date-suffix-regexp
  (format "\\[%s \\(%s\\]\\)" my/org-timestamp-date-re my/org-timestamp-timed-suffix-re)
  "Regexp matching the right half of an inactive Org timestamp.")

(defconst my/org-inactive-date-suffix-day-only-regexp
  (format "\\[%s \\(%s\\]\\)" my/org-timestamp-date-re my/org-timestamp-day-only-re)
  "Regexp matching the right half of an inactive all-day Org timestamp.")

(defconst my/org-timestamp-badge-style
  '(:font-size 13
    :height 0.58
    :padding 1.8
    :radius 1.6
    :stroke 0)
  "Compact style for timestamp SVG badges.")

(defconst my/org-all-day-timestamp-badge-style
  '(:font-size 10
    :height 0.5
    :padding 0.05
    :radius 0
    :stroke 0)
  "More compact style for all-day timestamp SVG badges.")

(defun my/org-format-timestamp-date (tag)
  (when (string-match my/org-timestamp-date-re tag)
    (let* ((date (match-string 0 tag))
           (parts (mapcar #'string-to-number (split-string date "-")))
           (year (nth 0 parts))
           (month (nth 1 parts))
           (day (nth 2 parts))
           (time (encode-time 0 0 0 day month year)))
      (format "%02d %s" day (format-time-string "%b" time)))))

(defun my/org-format-timestamp-suffix (tag)
  (cond
   ((or (string-suffix-p "]" tag)
        (string-suffix-p ">" tag))
    (substring tag 0 -1))
   (t tag)))

(defun my/org-make-timestamp-badge (label face &rest properties)
  (apply #'my/org-svg-tag label face (append properties my/org-timestamp-badge-style)))

(defun my/org-make-all-day-timestamp-badge (label face &rest properties)
  (apply #'my/org-svg-tag label face (append properties my/org-all-day-timestamp-badge-style)))

(defun my/org-timestamp-badge-spec (date-face)
  `((,my/org-active-date-regexp
     . ((lambda (tag)
          (my/org-make-timestamp-badge
           (my/org-format-timestamp-date tag)
           ',date-face))))
    (,my/org-active-date-prefix-day-only-regexp
     . ((lambda (tag)
          (my/org-make-all-day-timestamp-badge
           (my/org-format-timestamp-date tag)
           ',date-face
           :crop-right t))))
    (,my/org-active-date-suffix-day-only-regexp
     . ((lambda (tag)
          (my/org-make-all-day-timestamp-badge
           (my/org-format-timestamp-suffix tag)
           ',date-face
           :crop-left t
           :inverse t))))
    (,my/org-active-date-prefix-regexp
     . ((lambda (tag)
          (my/org-make-timestamp-badge
           (my/org-format-timestamp-date tag)
           ',date-face
           :crop-right t))))
    (,my/org-active-date-suffix-regexp
     . ((lambda (tag)
          (my/org-make-timestamp-badge
           (my/org-format-timestamp-suffix tag)
           ',date-face
           :crop-left t
           :inverse t))))
    (,my/org-inactive-date-regexp
     . ((lambda (tag)
          (my/org-make-timestamp-badge
           (my/org-format-timestamp-date tag)
           ',date-face))))
    (,my/org-inactive-date-prefix-day-only-regexp
     . ((lambda (tag)
          (my/org-make-all-day-timestamp-badge
           (my/org-format-timestamp-date tag)
           ',date-face
           :crop-right t))))
    (,my/org-inactive-date-suffix-day-only-regexp
     . ((lambda (tag)
          (my/org-make-all-day-timestamp-badge
           (my/org-format-timestamp-suffix tag)
           ',date-face
           :crop-left t
           :inverse t))))
    (,my/org-inactive-date-prefix-regexp
     . ((lambda (tag)
          (my/org-make-timestamp-badge
           (my/org-format-timestamp-date tag)
           ',date-face
           :crop-right t))))
    (,my/org-inactive-date-suffix-regexp
     . ((lambda (tag)
          (my/org-make-timestamp-badge
           (my/org-format-timestamp-suffix tag)
           ',date-face
           :crop-left t
           :inverse t))))))

(defun my/org-agenda-show-svg ()
  (when (require 'svg-tag-mode nil t)
    (remove-overlays (point-min) (point-max) 'my/org-agenda-svg-tag t)
    (dolist (item svg-tag-tags)
      (pcase-let ((`(,pattern ,subexp ,props-form)
                   (svg-tag--build-keywords item)))
        (save-excursion
          (goto-char (point-min))
          (while (re-search-forward pattern nil t)
            (let ((props (eval props-form))
                  (overlay (make-overlay (match-beginning subexp)
                                         (match-end subexp))))
              (overlay-put overlay 'my/org-agenda-svg-tag t)
              (while props
                (overlay-put overlay (pop props) (pop props))))))))))

(defun my/prettify-symbols-setup ()
  (setq-local prettify-symbols-alist
              '((":END:" . " ")
                (":ID:" . "󰿀 ")
                ("#+title:" . "󰛼 ")
                ("title:" . "󰛼 ")))

  (prettify-symbols-mode 1))



(defun my/svg-progress-percent (value)
  (let* ((progress (my/org-clamp-progress (/ (string-to-number value) 100.0)))
         (face (my/org-progress-face progress))
         (foreground (my/org-svg-face-foreground face))
         (background (my/org-svg-face-background face))
         (track (my/org-svg-face-background 'my/org-badge-muted-face)))
    (svg-image (svg-lib-concat
                (svg-lib-progress-bar progress nil
                                      :margin 0 :stroke 2 :radius 3 :padding 2 :width 11
                                      :foreground foreground :background track)
                (svg-lib-tag (concat value "%") nil
                             :foreground foreground :background background
                             :stroke 0 :margin 0))
               :ascent 'center)))

(defun my/svg-progress-count (value)
  (let* ((seq (mapcar #'string-to-number (split-string value "/")))
         (count (float (car seq)))
         (total (float (cadr seq)))
         (progress (my/org-clamp-progress (if (> total 0.0) (/ count total) 0.0)))
         (face (my/org-progress-face progress))
         (foreground (my/org-svg-face-foreground face))
         (background (my/org-svg-face-background face))
         (track (my/org-svg-face-background 'my/org-badge-muted-face)))
    (svg-image (svg-lib-concat
                (svg-lib-progress-bar progress nil
                                      :margin 0 :stroke 2 :radius 3 :padding 2 :width 11
                                      :foreground foreground :background track)
                (svg-lib-tag value nil
                             :foreground foreground :background background
                             :stroke 0 :margin 0))
               :ascent 'center)))

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
            ("M-RET" . org-open-at-point))
     :config
     (require 'org-indent)
     (my/org-ensure-theme-refresh-hooks)
     (my/org-setup-faces))

(use org-roam
     ; TODO: move to specialized (use-builtin) later
     :straight nil
     :ensure nil
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
     (meow-normal-define-key
       '("M-L" . completion-at-point))
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

(use svg-tag-mode
  :config
  ;; `svg-tag-mode` owns priority, progress, and date-oriented badges.
  (setq svg-tag-tags
        (append
         `(
            ;; Metadata
             (":PROPERTIES:" . ((lambda (_tag)
                                  (my/org-meta-icon-badge "cog" 'my/org-badge-muted-face "⚙"))))
             (":LOGBOOK:" . ((lambda (_tag)
                                (my/org-meta-icon-badge "pencil" 'my/org-badge-muted-face "✎"))))
             ("CLOSED:" . ((lambda (_tag)
                              (my/org-meta-icon-badge "check" 'my/org-badge-date-face "✓"))))
             ("CLOCK:" . ((lambda (_tag)
                             (my/org-meta-icon-badge "clock-outline" 'my/org-badge-date-face "◷"))))

           ;; Todo states
           ("TODO" . ((lambda (tag)
                        (my/org-svg-tag tag 'my/org-badge-progress-face))))
           ("DONE" . ((lambda (tag)
                         (my/org-svg-tag tag 'my/org-badge-progress-done-face))))

           ;; Task priority
           ("\\[#[A-Z]\\]" . ((lambda (tag)
                                  (my/org-svg-tag tag 'my/org-badge-priority-face
                                                  :beg 2 :end -1))))

           ;; Progress
           ("\\(\\[[0-9]\\{1,3\\}%\\]\\)" . ((lambda (tag)
                                                     (my/svg-progress-percent (substring tag 1 -2)))))
           ("\\(\\[[0-9]\\+/[0-9]\\+\\]\\)" . ((lambda (tag)
                                                       (my/svg-progress-count (substring tag 1 -1))))))
          (my/org-timestamp-badge-spec 'my/org-badge-date-face))))


;; Hook registration

(add-hook 'org-mode-hook #'my/org-mode-setup)
(add-hook 'org-mode-hook #'my/prettify-symbols-setup)
(add-hook 'org-mode-hook #'svg-tag-mode)
(add-hook 'org-agenda-mode-hook #'my/prettify-symbols-setup)
(add-hook 'org-agenda-finalize-hook #'my/org-agenda-show-svg)

(provide 'mod-org)
