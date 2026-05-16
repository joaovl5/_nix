---
name: janet-development
description: Use when editing, reviewing, or debugging Janet code; covers syntax, core data, bindings, control flow, macros, PEGs, process interop, and common mistakes
---

Use this for Janet language work and Janet project scripts in this repo. Start with `references/core-language.md`; load the other refs when the task touches macros, PEGs, or processes.

## What lives where

- **Core language:** `references/core-language.md`
- **Macros:** `references/macros.md`
- **PEGs:** `references/peg.md`
- **Processes and JPM:** `references/processes.md`

## High-signal reminders

- **Parser model:** Janet parses code into data. `()` is a call tuple, `[]` is a literal tuple, and `@[]`/`@{}` make mutable arrays and tables
- **Truthiness:** only `nil` and `false` are falsey
- **Bindings:** `def` is immutable, `var` is mutable, `set` updates state, and `let` is the default for locals
- **Functions:** `fn`/`defn` return the last body form; use `&opt`, `&`, `&keys`, or `&named` when the call shape needs it
- **Comparison:** use `=`/`not=` for equality and `deep=` for mutable contents; `!=` is not Janet syntax
- **Macros:** prefer functions first; use macros only for compile-time rewrites, and expand suspicious forms with `macex1` or `macex`
- **PEGs:** reach for PEGs when regex gets brittle; they are Janet’s parsing escape hatch
- **Processes:** pass argv data, not shell strings; use the project’s wrapper or `spork/sh` only when that fits the job

## Checks

- **Workflow:** format first, then run the focused Janet script or test, then lint the touched path if the repo provides a checker
- **Common mistakes:** mutating the wrong type, treating `=` as deep equality, using `!=`, or writing a macro when a function would do

## More detail

- `references/core-language.md` covers the core data model, scope, flow, equality, and errors
- `references/macros.md` covers compile-time rewriting, hygiene, and expansion
- `references/peg.md` covers parsing expression grammars and capture idioms
- `references/processes.md` covers shell/process helpers, JPM, and repo script workflow
