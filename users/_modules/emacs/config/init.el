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

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(confirm-kill-processes nil)
 '(custom-safe-themes
   '("720838034f1dd3b3da66f6bd4d053ee67c93a747b219d1c546c41c4e425daf93"
     "7c3d62a64bafb2cc95cd2de70f7e4446de85e40098ad314ba2291fc07501b70c"
     "b99ff6bfa13f0273ff8d0d0fd17cc44fab71dfdc293c7a8528280e690f084ef0"
     "4b88b7ca61eb48bb22e2a4b589be66ba31ba805860db9ed51b4c484f3ef612a7"
     "fffef514346b2a43900e1c7ea2bc7d84cbdd4aa66c1b51946aade4b8d343b55a"
     "f053f92735d6d238461da8512b9c071a5ce3b9d972501f7a5e6682a90bf29725"
     "38b43b865e2be4fe80a53d945218318d0075c5e01ddf102e9bec6e90d57e2134"
     "0325a6b5eea7e5febae709dab35ec8648908af12cf2d2b569bedc8da0a3a81c1"
     "19d62171e83f2d4d6f7c31fc0a6f437e8cec4543234f0548bad5d49be8e344cd"
     "13096a9a6e75c7330c1bc500f30a8f4407bd618431c94aeab55c9855731a95e1"
     "9b9d7a851a8e26f294e778e02c8df25c8a3b15170e6f9fd6965ac5f2544ef2a9"
     default)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:family "Iosevka Nerd Font" :height 250))))
 '(dired-broken-symlink ((t (:background "brown" :foreground "navajo white" :weight bold))))
 '(doom-modeline ((t nil)))
 '(error ((t (:foreground "#ff6c6b"))))
 '(fixed-pitch ((t (:family "Iosevka Nerd Font" :height 230))))
 '(font-lock-function-name-face ((t (:family "Iosevka Nerd Font" :slant italic))))
 '(font-lock-variable-name-face ((t (:family "Iosevka Nerd Font" :weight bold))))
 '(line-number-current-line ((t (:foreground "yellow" :inherit line-number))))
 '(mode-line ((t (:family "Iosevka Nerd Font" :weight Bold)))))
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.

