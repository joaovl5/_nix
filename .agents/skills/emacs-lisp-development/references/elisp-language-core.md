# Emacs Lisp Core Language Reference

## Functions and commands

```elisp
(defun greet (name)
  "Greet NAME."
  (format "Hello, %s!" name))

(lambda (x) (+ x 1))
```

Interactive forms make a function callable from `M-x`:

```elisp
(defun greet-user ()
  "Greet the current user."
  (interactive)
  (message "Hello, %s!" user-login-name))

(defun insert-date ()
  "Insert today's date at point."
  (interactive "*")
  (insert (format-time-string "%Y-%m-%d")))
```

Useful interactive codes: `"*"` errors if the buffer is read-only; `"r"` passes region bounds; `"s"` reads a string; `"n"` reads a number; `"d"` passes point.

## Variables and scope

```elisp
(defvar my-mode-map nil "Keymap for my-mode.")
(defcustom my-threshold 80 "Warning column." :type 'integer :group 'convenience)
(defconst my-version "1.0" "Current version.")
(defvar-local my-buffer-flag nil "Buffer-local state.")
```

- `defvar` declares a special dynamically scoped variable and does not re-evaluate if already bound.
- `defcustom` integrates with Customize.
- `defconst` signals intent that the value should not change.
- `defvar-local` is shorthand for `defvar` plus buffer-local behavior.
- `let` evaluates all init forms in the outer scope; `let*` evaluates sequentially.
- `setq-local` creates/sets a buffer-local binding.
- `setq-default` sets the default value of a buffer-local variable.

## Data structures

- Lists are chains of cons cells ending in `nil`: `(list 1 2 3)`.
- Alists are `((key . value) ...)`; use `alist-get`, `assoc`, or `assq`.
- Plists are `(:key value ...)`; use `plist-get` and `plist-member`.
- Vectors are fixed-length and O(1) for indexed access.
- Records are vectors with a type symbol in slot 0; use `cl-defstruct`.
- Hash tables support `eq`, `eql`, or `equal` tests; use `equal` for string keys.

## Control flow and cleanup

```elisp
(if cond then-branch else-branch)
(when cond body...)
(unless cond body...)
(cond
 (test1 body1)
 (test2 body2)
 (t fallback))
(pcase expr
  (`(,a ,b) (list b a))
  ('symbol  "matched symbol")
  (_        "fallback"))
```

- `progn` returns the last value.
- `prog1` returns the first value.
- `prog2` returns the second value.

```elisp
(condition-case err
    (save-buffer)
  (user-error
   (message "%s" (error-message-string err)))
  (error
   (message "Unexpected failure: %s" (error-message-string err))))

(with-demoted-errors "my-mode: %S"
  (cleanup-cache))

(unwind-protect
    (progn
      (acquire-resource)
      (do-work))
  (release-resource))
```

Use `ignore-errors` only when discarding failures is intentional.

## Iteration

```elisp
(dolist (item list)
  (process item))

(dotimes (i 10)
  (insert (number-to-string i)))

(cl-loop for x in list
         when (> x 3)
         collect (* x x))
```

Prefer `mapc` over `mapcar` when you do not need the returned list. Prefer `seq-*` functions when working with mixed sequence types.

## Strings and regex

Emacs regex differs from PCRE:

- Grouping uses `\(` and `\)`, not plain `(` and `)`.
- Alternation is `\|`.
- `+` and `?` are postfix operators; interval repetition uses `\{n,m\}` in regexp syntax.
- Backreferences use `\1`.
- Use POSIX classes such as `[[:alpha:]]`; PCRE shorthands like `\w` and `\d` are not portable here.

In Lisp strings, double-escape backslashes: regexp `\(` becomes string `"\\("`.

Useful functions: `string-match-p`, `looking-at-p`, `re-search-forward`, `replace-regexp-in-string`, `replace-match`.

## Buffers, hooks, and advice

```elisp
(with-current-buffer "*scratch*"
  (goto-char (point-max))
  (insert "\nNew line"))

(save-excursion
  (goto-char (point-min))
  (re-search-forward "pattern" nil t)
  (match-string 0))
```

```elisp
(defun my-prog-mode-setup ()
  (display-line-numbers-mode 1))

(add-hook 'prog-mode-hook #'my-prog-mode-setup)
(add-hook 'before-save-hook #'whitespace-cleanup nil t)
(remove-hook 'prog-mode-hook #'my-prog-mode-setup)
```

Third arg `t` makes a hook buffer-local.

```elisp
(defun my-kill-buffer-around (old-fn &rest args)
  (apply old-fn args))

(advice-add 'kill-buffer :around #'my-kill-buffer-around)
(advice-remove 'kill-buffer #'my-kill-buffer-around)
```

Advice types: `:before`, `:after`, `:around`, `:override`.

## Compact example

```elisp
;;; my-search.el --- Enhanced search utilities -*- lexical-binding: t; -*-

(require 'seq)

(defgroup my-search nil
  "Enhanced search utilities."
  :group 'convenience)

(defcustom my-search-case-fold 'smart
  "Case folding strategy: t, nil, or `smart'."
  :type '(choice (const :tag "Always" t)
                 (const :tag "Never" nil)
                 (const :tag "Smart" smart))
  :group 'my-search)

(defun my-search--smart-case-p (pattern)
  (not (seq-some #'uppercase-p pattern)))

(defun my-search-in-buffer (pattern &optional backward)
  "Search for PATTERN in current buffer.
With BACKWARD non-nil, search backward."
  (let ((case-fold-search
         (pcase my-search-case-fold
           ('smart (my-search--smart-case-p pattern))
           (v v))))
    (if backward
        (re-search-backward pattern nil t)
      (re-search-forward pattern nil t))))

(provide 'my-search)
;;; my-search.el ends here
```
