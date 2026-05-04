---
name: emacs-lisp-development
description: Use when reading, writing, or reviewing Emacs Lisp code; covers language semantics, idiomatic patterns, standard library, and common mistakes
---

For repo-specific Emacs configuration, package setup, and keybindings, also load `emacs-configuration`

## First pass

- **Scope:** use this skill for language behavior, APIs, macros, and runtime patterns
- **References:** keep this file as the short map; load only the reference files that match the task
- **Lexical binding:** start new files with `;; -*- lexical-binding: t; -*-`
- **Namespaces:** variables and functions live in separate namespaces; use `funcall` for function values
- **Strings:** treat strings as mutable arrays; use `concat`, `format`, or `copy-sequence` when you need fresh data
- **Regex predicates:** prefer `string-match-p` when you only need a boolean and want match data left alone
- **Macros:** use a macro only when you need unevaluated code; use `cl-gensym` or `cl-with-gensyms` for fresh names
- **Declared state:** use `defvar`, `defcustom`, `defconst`, or `defvar-local` before `setq`
- **Hooks and advice:** prefer named functions when callers may remove, reuse, or inspect them
- **Cleanup:** use `condition-case` for expected failures and `unwind-protect` for cleanup

## Quick reminders

- **Lexical closures:** capture bindings from the enclosing environment; shared bindings still reflect later mutation
- **Special vars:** `defvar`, `defcustom`, and `defconst` stay dynamically scoped even with lexical binding
- **Buffer locals:** use `setq-local` for buffer-local values and `setq-default` for defaults
- **Loading:** `require` loads a feature, `provide` registers it, `autoload` defers it, and `with-eval-after-load` patches after load
- **`use-package`:** treat it as configuration machinery; for repo-specific package setup, load `emacs-configuration`

## Common mistakes

- **Missing header:** forgetting `lexical-binding: t` in new files
- **Equality:** use `eq` for identity and `equal` for structural equality
- **Function values:** forgetting `funcall` for a function stored in a variable
- **Shared strings:** mutating string literals or reused strings in place
- **Regex escaping:** regexp `\(` is string `"\\("`
- **Undeclared state:** using `setq` on undeclared variables
- **`set` vs `setq`:** `setq` takes a symbol literally; `set` evaluates its first argument
- **Match data:** assuming match data survives later searches
- **Advice:** using `fset` to advise instead of `advice-add`
- **Indexed access:** assuming list length is O(1) instead of using vectors

## References

- **Language core:** `references/elisp-language-core.md` covers functions, scope, data, control flow, regex, hooks, advice, and the compact example
- **Patterns:** `references/elisp-patterns.md` covers modes, keymaps, overlays, timers, processes, windows, faces, text properties, `cl-lib`, repeat maps, and async
- **Stdlib:** `references/elisp-stdlib.md` is the API index for common built-ins
