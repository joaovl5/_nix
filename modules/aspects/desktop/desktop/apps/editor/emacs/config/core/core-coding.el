;; -*- lexical-binding: t; -*-

(use flycheck
     :ensure t
     :init
     (global-flycheck-mode))

(use devdocs
  :ensure t
  :bind (("C-c c d" . devdocs-search)))

;; formatting
(use apheleia
  :ensure t
  :init
  (setq apheleia-formatters
        '((ruff . ("ruff" "format" "--silent" "--stdin-filename" filepath "-")))
        apheleia-mode-alist
        '((python-mode . ruff)))
  :config
  (apheleia-global-mode +1))
(provide 'core-coding)
