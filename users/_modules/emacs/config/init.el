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


;; Disable wrapping by default due to its performance cost.
(setq-default truncate-lines t)

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
(defvar modules-dir (expand-file-name "core" root-dir)
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

(message "[!] loading core modules...")

(require 'core-packages)
(require 'core-ui)
(require 'core-core)
(require 'core-keys)
(require 'core-views)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(confirm-kill-processes nil)
 '(custom-safe-themes
   '("0325a6b5eea7e5febae709dab35ec8648908af12cf2d2b569bedc8da0a3a81c1"
     "19d62171e83f2d4d6f7c31fc0a6f437e8cec4543234f0548bad5d49be8e344cd"
     "13096a9a6e75c7330c1bc500f30a8f4407bd618431c94aeab55c9855731a95e1"
     "9b9d7a851a8e26f294e778e02c8df25c8a3b15170e6f9fd6965ac5f2544ef2a9"
     default)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 ; '(default ((t (:inherit nil :extend t :stipple nil :background "#282c34" :foreground "#bbc2cf" :inverse-video nil :box nil :strike-through nil :overline nil :underline nil :slant normal :weight regular :height 251 :width normal :foundry "UKWN" :family "Iosevka Nerd Font"))))
 '(dired-broken-symlink ((t (:background "brown" :foreground "navajo white" :weight bold))))
 '(doom-modeline ((t nil)))
 '(error ((t (:foreground "#ff6c6b"))))
 ; '(fixed-pitch ((t (:family "Iosevka Nerd Font" :height 230))))
 '(font-lock-function-name-face ((t (:family "Iosevka Nerd Font" :slant italic))))
 '(font-lock-variable-name-face ((t (:family "Iosevka Nerd Font" :weight bold))))
 '(line-number-current-line ((t (:foreground "yellow" :inherit line-number))))
 '(mode-line ((t (:family "Iosevka Nerd Font" :weight Bold)))))
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.

