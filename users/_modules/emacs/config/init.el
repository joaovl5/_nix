;; Set-language-environment sets default-input-method, which is unwanted.
(setq default-input-method nil)

;; By default, Emacs "updates" its ui more often than it needs to
(setq which-func-update-delay 1.0)
; (setq idle-update-delay which-func-update-delay)  ;; Obsolete in >= 30.1

(defalias #'view-hello-file #'ignore)  ; Never show the hello file

;; Disable fontification during user input to reduce lag in large buffers.
;; Also helps marginally with scrolling performance.
(setq redisplay-skip-fontification-on-input t)

;; Avoid automatic frame resizing when adjusting settings.
(setq global-text-scale-adjust-resizes-frames nil)

;; A longer delay can be annoying as it causes a noticeable pause after each
;; deletion, disrupting the flow of editing.
(setq delete-pair-blink-delay 0.03)

;; Disable visual indicators in the fringe for buffer boundaries and empty lines
(setq-default indicate-buffer-boundaries nil)
(setq-default indicate-empty-lines nil)

;; Continue wrapped lines at whitespace rather than breaking in the
;; middle of a word.
(setq-default word-wrap t)

;; shut up about the themes
(setq custom-safe-themes t)

;; Disable wrapping by default due to its performance cost.
(setq-default truncate-lines t)

;; clipboard sharing w/ system
(setq select-enable-clipboard t
      select-enable-primary t)

;;
(setq vc-follow-symlinks nil)

;; compilation
(setq comp-deferred-compilation t)
(setq warning-suppress-log-types '((comp)))


;; Perf: Reduce command completion overhead.
(setq read-extended-command-predicate #'command-completion-default-include-p)

(defvar username
  (getenv "USER"))

(message "[!] starting... be patient, %s!" username)

;; Always load newest byte code
(setq load-prefer-newer t)

(defvar root-dir (file-name-directory load-file-name)
  "The root dir of the Emacs config.")
(defvar core-dir (expand-file-name "core" root-dir)
  "Directory for core functionality.")
(defvar modules-dir (expand-file-name "modules" root-dir)
  "Directory for modules.")
(defvar savefile-dir (expand-file-name "savefile" user-emacs-directory)
  "This folder stores all the automatically generated save/history-files.")

(unless (file-exists-p savefile-dir)
  (make-directory savefile-dir))

(add-to-list 'load-path core-dir)
(add-to-list 'load-path modules-dir)

;; reduce the frequency of garbage collection by making it happen on
;; each 50MB of allocated data (the default is on every 0.76MB)
(setq gc-cons-threshold 50000000)

;; warn when opening files bigger than 100MB
(setq large-file-warning-threshold 100000000)

(message "[!] loading core...")

(require 'core-packages)
(require 'core-ui)
(require 'core-core)
(require 'core-keys)
(require 'core-views)
(require 'core-coding)

(message "[!] loading modules...")

(require 'mod-org)
(require 'mod-lisp)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(confirm-kill-processes nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(dired-broken-symlink ((t (:background "brown" :foreground "navajo white" :weight bold))))
 '(doom-modeline ((t nil)))
 '(error ((t (:foreground "#ff6c6b"))))
 '(line-number-current-line ((t (:foreground "yellow" :inherit line-number)))))
