(use org-roam
     ; TODO: move to specialized (use-builtin) later
     :straight nil
     :ensure nil
     :custom
     (org-roam-directory (file-truename "~/org/"))
     :bind (("C-c o t" . org-roam-buffer-toggle)
            ("C-c o f" . org-roam-node-find)
            ("C-c o g" . org-roam-graph)
            ("C-c o i" . org-roam-node-insert)
            ("C-c o c" . org-roam-capture)
            ("C-c o d" . org-roam-dailies-capture-today))
     :config
      (setq org-roam-node-display-template (concat "${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
      (org-roam-db-autosync-mode)
      ;; If using org-roam-protocol
      (require 'org-roam-protocol))




(provide 'mod-org)
