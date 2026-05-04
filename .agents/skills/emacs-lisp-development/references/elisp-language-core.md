# Emacs Lisp Core Language Reference

## Functions and commands

```elisp
(defun greet (name)
  "Greet NAME."
  (format "Hello, %s!" name))

(lambda (x) (+ x 1))
```

- **Commands:** add `(interactive ...)` only when the function is a command
- **Interactive codes:** `"*"` errors on read-only buffers, `"r"` passes region bounds, `"s"` reads a string, `"n"` reads a number, and `"d"` passes point

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

## Variables and scope

```elisp
(defvar my-mode-map nil "Keymap for my-mode.")
(defcustom my-threshold 80 "Warning column." :type 'integer :group 'convenience)
(defconst my-version "1.0" "Current version.")
(defvar-local my-buffer-flag nil "Buffer-local state.")
```

- **`defvar`:** declares a special dynamically scoped variable and skips re-evaluation when already bound
- **`defcustom`:** integrates with Customize
- **`defconst`:** signals intent that the value should not change
- **`defvar-local`:** combines `defvar` with buffer-local behavior
- **`let` vs `let*`:** `let` evaluates init forms in the outer scope, `let*` does it sequentially
- **`setq-local`:** creates or sets a buffer-local binding
- **`setq-default`:** sets the default value for a buffer-local variable

## Data structures

- **Lists:** chains of cons cells ending in `nil`, as in `(list 1 2 3)`
- **Alists:** `((key . value) ...)`; use `alist-get`, `assoc`, or `assq`
- **Plists:** `(:key value ...)`; use `plist-get` and `plist-member`
- **Vectors:** fixed-length and O(1) for indexed access
- **Records:** vectors with a type symbol in slot 0; use `cl-defstruct`
- **Hash tables:** support `eq`, `eql`, or `equal` tests; use `equal` for string keys

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

- **`progn`:** returns the last value
- **`prog1`:** returns the first value
- **`prog2`:** returns the second value

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

- **Ignored failures:** use `ignore-errors` only when discarding failures is intentional

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

- **Side effects:** prefer `mapc` over `mapcar` when you do not need the returned list
- **Mixed sequences:** prefer `seq-*` helpers when the input may be a list, vector, or string

## Strings and regex

- **Grouping:** use `\(` and `\)`, not plain `(` and `)`
- **Alternation:** use `\|`
- **Quantifiers:** `+` and `?` are postfix operators; interval repetition uses `\{n,m\}`
- **Backreferences:** use `\1`
- **Classes:** prefer POSIX classes like `[[:alpha:]]`; `\w` and `\d` are not portable here
- **Escaping:** in Lisp strings, double-escape backslashes so regexp `\(` becomes string `"\\("`
- **Useful APIs:** `string-match-p`, `looking-at-p`, `re-search-forward`, `replace-regexp-in-string`, `replace-match`

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

- **Buffer-local hooks:** pass `t` as the fourth arg to `add-hook` or `remove-hook`
- **Advice kinds:** use `:before`, `:after`, `:around`, or `:override`

```elisp
(defun my-kill-buffer-around (old-fn &rest args)
  (apply old-fn args))

(advice-add 'kill-buffer :around #'my-kill-buffer-around)
(advice-remove 'kill-buffer #'my-kill-buffer-around)
```

## Compact example

```elisp
;;; my-search.el --- Enhanced search utilities -*- lexical-binding: t; -*-

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
  (not (string-match-p "[[:upper:]]" pattern)))

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
