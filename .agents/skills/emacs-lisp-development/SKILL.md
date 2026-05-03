---
name: emacs-lisp-development
description: Use when reading, writing, or reviewing Emacs Lisp code; covers language semantics, idiomatic patterns, standard library, and common mistakes.
---

For repo-specific Emacs configuration, package setup, and keybindings, also load `emacs-configuration`.

## Mental model

- Lisp-2: variables and functions are separate namespaces. Use `funcall` for a function object stored in a variable.
- Dynamic binding is the default unless the file declares lexical binding.
- Everything is an expression.
- Symbols are interned objects, not just strings.

## First line for new files

```elisp
;; -*- lexical-binding: t; -*-
```

Why it matters:

- Closures capture lexical bindings from the enclosing environment; shared bindings share later mutation.
- Lexical scope prevents callers from shadowing free variables accidentally.
- The byte compiler can optimize lexical closures.
- Variables declared with `defvar`, `defcustom`, or `defconst` are always dynamically scoped, even with lexical binding.

## Core patterns

- Use `defun` for functions and add `(interactive ...)` only when the function is a command.
- Use `cl-defun` when keyword or optional arguments make the API clearer.
- Use `defvar`, `defcustom`, `defconst`, and `defvar-local` for declared state.
- Use `setq-local` for buffer-local values and `setq-default` for defaults.
- Prefer named functions for reusable/removable hooks and advice; anonymous lambdas are supported but easier to duplicate or lose.
- Use `condition-case` for expected error classes, `user-error` for caller-facing failures, and `unwind-protect` for cleanup.
- Strings are mutable arrays; use `concat`, `format`, or `copy-sequence` when you need fresh data.

## Loading and macros

```elisp
(require 'cl-lib)
(require 'magit)
(provide 'my-module)
```

- `require` loads a feature from `load-path`.
- `provide` registers the feature; conventionally place it at the end of the file.
- `autoload` defers loading until a function is first called.
- `with-eval-after-load` runs code after a feature loads.
- Use macros only when you need unevaluated code as input; if a function works, prefer it.
- Use `cl-gensym` or `cl-with-gensyms` for generated names in macros.

## `use-package`

`use-package` is configuration/package machinery, not core language. For repo-specific load order and package management, load `emacs-configuration`. If you encounter it elsewhere: `:preface` and `:init` run before package load, `:config` runs after load, and `:commands`/`:bind`/`:hook` commonly establish deferred entry points.

## Common mistakes

- Missing `lexical-binding: t` in new files.
- Confusing `eq`/`eql`/`equal`: use `eq` for identity and `equal` for structural equality.
- Forgetting `funcall` for function values.
- Mutating string literals or shared strings in place.
- Forgetting Emacs regex string escaping: regexp `\(` is string `"\\("`.
- Using `setq` on undeclared variables; use `defvar` first.
- Confusing `set` and `setq`: `setq` takes a symbol literally; `set` evaluates its first argument.
- Ignoring match-data lifetime; any new search clobbers it.
- Using `fset` to advise; use `advice-add`.
- Assuming list length is O(1); use vectors for indexed access.

## References

- `references/elisp-language-core.md`: core syntax, data structures, control flow, regex, hooks/advice, and compact example.
- `references/elisp-patterns.md`: idiomatic patterns for modes, keymaps, overlays, processes, windows, faces, text properties, CL, repeat maps, and async.
- `references/elisp-stdlib.md`: concise standard-library function index.
