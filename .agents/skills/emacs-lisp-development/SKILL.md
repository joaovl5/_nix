---
name: emacs-lisp-development
description: Use when reading, writing, or reviewing Emacs Lisp code; covers language semantics, idiomatic patterns, standard library, and common mistakes.
---

# Emacs Lisp Development

For repo-specific Emacs configuration matters, also load `emacs-configuration`.

This skill covers the **language**. Editor config, package setup, and keybindings belong to `emacs-configuration`.

## Mental model

- **Lisp-2**: separate namespaces for functions and variables. `foo` as a variable is unrelated to `foo` as a function. Use `funcall` to call a function object stored in a variable: `(funcall my-fn arg)`.
- **Dynamic binding by default**: free variables are dynamically scoped unless the file declares `lexical-binding: t`.
- **Everything is an expression**: no statements; every form returns a value.
- **Symbols are first-class**: symbols are interned objects, not just strings. `intern`, `make-symbol`, `symbol-name`, `symbol-value`, `symbol-function`.

## Lexical vs dynamic binding

Place this as the **first line** of every `.el` file (after file-local variables comment if any):

```elisp
;; -*- lexical-binding: t; -*-
```

Why it matters:

- **Closures**: with `lexical-binding: t`, `lambda` captures variables by value from enclosing `let`. Without it, closures see the current dynamic binding at call time.
- **Correctness**: dynamic scope means any caller can shadow your free variables. Lexical scope prevents this.
- **Performance**: the byte compiler can optimize lexical closures.
- **Special variables**: variables declared with `defvar`/`defcustom`/`defconst` are always dynamically scoped, even with `lexical-binding: t`. This is intentional — it lets you opt into dynamic scope for hooks and customization.

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

Interactive codes: `"*"` — error if buffer is read-only; `"r"` — region bounds; `"s"` — string from minibuffer; `"n"` — number; `"d"` — point position.

`cl-defun` for optional and keyword arguments:

```elisp
(cl-defun search-and-replace (pattern replacement &key (case-fold t) (whole-buffer nil))
  (let ((case-fold-search case-fold))
    (perform-replace pattern replacement whole-buffer nil nil)))
```

**Command vs function**: a command is any function with an `interactive` form. Call commands programmatically with `(command-execute #'foo)` or `(call-interactively #'foo)`.

## Variables and scope

```elisp
(defvar my-mode-map nil "Keymap for my-mode.")
(defcustom my-threshold 80 "Warning column." :type 'integer :group 'convenience)
(defconst my-version "1.0" "Current version.")
(defvar-local my-buffer-flag nil "Buffer-local state.")
```

- `defvar` — declares a special (dynamically scoped) variable. Does **not** re-evaluate if already bound.
- `defcustom` — like `defvar` but integrates with Customize.
- `defconst` — signals intent that the value should not change.
- `defvar-local` — shorthand for `defvar` + `make-variable-buffer-local`.

Bindings:

```elisp
(let ((a 1) (b 2))
  (+ a b))

(let* ((a 1) (b (+ a 10)))
  b)
```

`let` evaluates all init forms in the outer scope. `let*` evaluates sequentially.

Buffer-local values:

```elisp
(setq my-flag t)
(setq-local my-flag t)
(setq-default my-flag nil)
```

- `setq-local` — set a buffer-local value. Creates the buffer-local binding if needed.
- `setq-default` — set the default (global) value of a buffer-local variable.

## Data structures

### Lists

Cons cells are the foundation: `(cons 1 2)` → `(1 . 2)`.

Proper lists are chains ending in `nil`: `(list 1 2 3)` → `(1 2 3)`.

Association lists (alists): `((key1 . val1) (key2 . val2))`. Lookup: `alist-get`, `assoc`, `assq`.

Property lists (plists): `(:key1 val1 :key2 val2)`. Lookup: `plist-get`, `plist-member`.

### Vectors and records

Vectors are fixed-length, O(1) access: `[1 2 3]`.

Records are vectors with a type symbol in slot 0: `(cl-defstruct my-point x y)` creates a record type.

### Hash tables

```elisp
(let ((ht (make-hash-table :test #'equal)))
  (puthash "key" "value" ht)
  (gethash "key" ht)
  (remhash "key" ht)
  (maphash (lambda (k v) (message "%s -> %s" k v)) ht))
```

`:test` accepts `eq`, `eql`, or `equal`. Use `equal` for string keys.

### Strings

Strings are immutable. Build new ones:

```elisp
(concat "hello" " " "world")
(format "%s has %d items" name count)
```

## Control flow

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
(cl-case key
  (:foo "foo")
  (:bar "bar")
  (otherwise "default"))
```

Grouping: `progn` returns last value. `prog1` returns first value. `prog2` returns second.

## Iteration

```elisp
(dolist (item list)
  (process item))

(dotimes (i 10)
  (insert (number-to-string i)))

(cl-loop for x in list
         when (> x 3)
         collect (* x x))

(cl-loop for i from 0 below 10
         sum i into total
         finally return total)
```

Functional:

```elisp
(mapcar #'1+ '(1 2 3))
(mapc (lambda (x) (insert x)) items)
(mapconcat #'identity strings ", ")
(seq-map #'1+ seq)
(seq-filter #'cl-plusp numbers)
(cl-reduce #'+ numbers :initial-value 0)
```

Prefer `mapc` over `mapcar` when you don't need the return list. Prefer `seq-*` functions when working with mixed sequence types.

## Strings and regex

Emacs regex differs from PCRE:

| Feature           | Emacs               | PCRE            |
| ----------------- | ------------------- | --------------- |
| Grouping          | `\(` `\)`           | `(` `)`         |
| Alternation       | `\|`                | `\|` or `\|`    |
| Any char          | `.`                 | `.`             |
| Quantifier        | `\+` `\?` `\{n,m\}` | `+` `?` `{n,m}` |
| Backreference     | `\1`                | `\1` or `$1`    |
| Shorthand classes | `[[:alpha:]]`       | `\w` `\d`       |

Key functions:

```elisp
(string-match-p "\\`[0-9]+" str)
(looking-at-p "[a-z]+")
(re-search-forward "pattern" nil t)
(replace-regexp-in-string "[0-9]+" "#" str)
(replace-match "replacement" t t)
```

Use `string-match-p` / `looking-at-p` (predicate) when you only need a boolean. Use `string-match` when you need match data (`match-string`, `match-beginning`, `match-end`).

Remember to double-escape backslashes in strings: `"\\("` in elisp = `\(` in regex.

## Buffers and windows

```elisp
(with-current-buffer "*scratch*"
  (goto-char (point-max))
  (insert "\nNew line"))

(save-excursion
  (goto-char (point-min))
  (re-search-forward "pattern" nil t)
  (match-string 0))

(with-temp-buffer
  (insert "temporary content")
  (buffer-string))
```

Key predicates and accessors:

- `point`, `point-min`, `point-max` — character positions
- `region-beginning`, `region-end` — active region bounds
- `buffer-substring` / `buffer-substring-no-properties` — extract text
- `buffer-string` — entire buffer contents
- `get-buffer`, `get-buffer-create`, `current-buffer`
- `insert`, `delete-region`, `delete-dups`

## Hooks and advice

```elisp
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'before-save-hook #'whitespace-cleanup nil t)
(remove-hook 'prog-mode-hook #'display-line-numbers-mode)
```

Third arg `t` makes the hook buffer-local. Always use **named functions**, not lambdas, so you can remove them later.

Advice:

```elisp
(advice-add 'find-file :before #'my-find-file-setup)
(advice-add 'kill-buffer :around
            (lambda (old-fn &rest args)
              (apply old-fn args)))
(advice-remove 'find-file #'my-find-file-setup)
```

Advice types: `:before` runs before. `:after` runs after. `:around` wraps (receives original function). `:override` replaces entirely.

## Macros (brief)

```elisp
(defmacro with-gensyms (syms &rest body)
  (declare (indent 1))
  `(let ,(mapcar (lambda (s) (list s '(gensym))) syms)
     ,@body))
```

- Backquote + comma for templates.
- Use `,@` to splice a list.
- `declare` with `(indent 1)` tells Emacs to indent body forms.
- Use macros only when you need **unevaluated code** as input. If a function works, prefer it.

## Loading and providing

```elisp
(require 'magit)
(provide 'my-module)
```

- `require` loads a feature by name, searching `load-path`.
- `provide` registers that the current file provides a feature.
- `autoload` defers loading until the function is first called.
- `with-eval-after-load` runs code after a feature loads:

```elisp
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c a") #'org-agenda))
```

Convention: `(provide 'my-module)` goes at the end of the file. The feature name usually matches the filename without `.el`.

## use-package patterns

```elisp
(use-package magit
  :ensure t
  :commands (magit-status magit-dispatch)
  :bind (("C-x g" . magit-status)
         ("C-x M-g" . magit-dispatch))
  :hook (git-commit-mode . flyspell-mode)
  :custom (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1)
  :init
  (setq magit-status-margin '(t "%Y-%m-%d %H:%M" magit-log-margin-width t 18))
  :config
  (transient-bind-q-to-quit))
```

Keyword execution order: `:ensure` → `:preface` → `:init` → `:commands`/`:bind`/`:hook` (defer) → `:config` (after load).

Deferred loading:

- `:commands` — autoload these commands; load package on first call.
- `:hook` — adds to hook; load package when hook runs.
- `:bind` — sets keybindings; load package on first key press.
- Without any of these, `:config` runs immediately at load time.

## Common mistakes

| Mistake                        | Fix                                                                                                                             |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| Missing `lexical-binding: t`   | Always add it. Enables closures and catches more errors.                                                                        |
| Using `lambda` in hooks/advice | Use named functions so you can remove them.                                                                                     |
| Confusing `eq`/`eql`/`equal`   | `eq` for identity (symbols, objects). `equal` for structural equality (strings, lists).                                         |
| Forgetting `funcall`           | In a Lisp-2, `(my-fn arg)` calls the function slot named `my-fn`. Use `(funcall my-fn arg)` when the function is in a variable. |
| Mutating strings               | Strings are immutable. Use `concat` or `format` to produce new ones.                                                            |
| Unescaped regex parens         | Emacs uses `\(` not `(`. In elisp strings: `"\\("`.                                                                             |
| `setq` on undeclared variables | Use `defvar` first. Silent `setq` creates dynamic bindings that leak.                                                           |
| `set` vs `setq`                | `setq` takes a symbol literally. `set` evaluates its first arg. Almost always want `setq`.                                      |
| Ignoring match data lifetime   | `match-string` uses the last search. Any new search clobbers it. Save results immediately.                                      |
| Using `fset` to advise         | Use `advice-add` instead. It composes properly with other advice.                                                               |
| Assuming list length is O(1)   | `length` on lists is O(n). Use vectors for indexed access.                                                                      |

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

Why this is idiomatic:

- `lexical-binding: t` on the first line.
- `defgroup`/`defcustom` for discoverable configuration.
- Private helper naming convention (`my-search--`).
- `pcase` for clean dispatch.
- `let` to temporarily bind a special variable.
- `provide` at the end, matching filename.
