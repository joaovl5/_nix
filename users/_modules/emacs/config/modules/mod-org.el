(use org
     :custom
     (org-log-done t)
     (org-src-fontify-natively t)
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
            ("M-h"  . nil)
            ("M-j"  . nil)
            ("M-k"  . nil)
            ("M-l"  . nil)
            ("M-RET"  . org-open-at-point)))

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
            ("C-c o d" . org-roam-dailies-capture-today))
     :config
      (setq org-roam-node-display-template (concat "${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
      (setq org-roam-completion-everywhere t)
      (org-roam-db-autosync-mode)
      (meow-normal-define-key
        '("M-L" . completion-at-point))
      ;; If using org-roam-protocol
      (require 'org-roam-protocol))

(use org-download
     :ensure t
     :bind (("C-c p p" . org-download-clipboard))
     :init
     (require 'org-download))


(provide 'mod-org)
