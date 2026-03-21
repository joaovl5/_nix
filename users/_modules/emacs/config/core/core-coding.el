;; -*- lexical-binding: t; -*-

(use flycheck
     :ensure t
     :init
     (global-flycheck-mode))

(use-package devdocs
  :ensure t
  :bind (("C-c c d" . devdocs-search)))


(provide 'core-coding)
