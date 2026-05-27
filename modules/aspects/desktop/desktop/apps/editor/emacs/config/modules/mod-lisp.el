;; mod-lisp.el --- Stuff for editing lisp  -*- lexical-binding: t; -*-

;;; Commentary:
;; Several things for editing Lisp code.

;;; Code:

(use parinfer-rust-mode
     :straight nil
     :ensure nil
     :hook emacs-lisp-mode
     :bind (("C-c ( w" . parinfer-rust-toggle-paren-mode)
            ("C-c ( t" . parinfer-rust-toggle-disable))


     :init
     (setq parinfer-rust-auto-download t))


(provide 'mod-lisp)
