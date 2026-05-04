---
name: fennel-development
description: Use when reading, writing, or reviewing Fennel code; covers syntax, semantics, macros, Lua interop, fennel-ls/flsproject workflow, and common mistakes
---

Use this for Fennel language work and repo Fennel tooling such as `flsproject.fnl`
For repo Neovim maintenance flow, also load `neovim-configuration`

- **Upstream refs:** <https://fennel-lang.org/tutorial>, <https://fennel-lang.org/reference>, <https://fennel-lang.org/macros>, <https://fennel-lang.org/lua-primer>

## Mental model

- **Runtime:** the code compiles to Lua, so Lua runtime semantics still apply
- **Forms:** `()` are calls or special forms, not runtime list objects; use `[]` for dense sequences and `{}` for tables
- **Modules:** files export their last value
- **`require`:** uses dotted names; embedded hosts need a Fennel loader or precompiled Lua
- **`include`:** pulls another module in at compile time and still emits runtime loading for that module

## Macros

- **When to use:** use macros for compile-time transformation; prefer functions for runtime helpers
- **Inputs:** macro arguments are code forms, not evaluated values
- **Templates:** quote AST with backtick, unquote with `,`, splice bodies with `,(unpack body)`
- **Fresh names:** introduced locals should usually use `#` gensyms
- **Macro modules:** shared macros live in macro modules and load with `import-macros`
- **Compiler scope:** macro modules run in compiler scope, not runtime
- **Helpers:** common compiler-scope helpers include `list`, `sym`, `gensym`, and `view`
- **Boundaries:** `macroexpand` and `in-scope?` are macro-only helpers; do not call them from arbitrary `eval-compiler` code

## Repo fennel-ls / flsproject rules

- **Source of truth:** `users/_modules/desktop/apps/editor/neovim/config/flsproject.fnl` is authoritative; `flsproject.lua` is generated
- **Generated file:** never hand-edit `flsproject.lua`; edit `flsproject.fnl` and regenerate
- **What it controls:** `flsproject.fnl` sets Lua version, Fennel path, macro path, Neovim library hints, and extra globals
- **Macro marker:** `users/_modules/desktop/apps/editor/neovim/config/fnl/lib/init-macros.fnl` must keep `;; fennel-ls: macro-file` as the exact first line
- **Project root:** this repo roots `fennel-ls` by searching upward for `flsproject.fnl`; moving that file changes project rooting
- **Neovim flow:** for broader maintenance and recompilation, load `neovim-configuration`

## Common mistakes

- **Forms:** treating `(...)` as runtime arrays
- **Arity:** assuming `fn` rejects missing required args; use `lambda` when missing args should fail loudly
- **Varargs:** treating `...` as a table
- **Equality:** assuming Lua tables compare by structure
- **Sparse sequences:** using `length` or `ipairs` on sparse sequences
- **Macros:** overusing macros for ordinary helpers
- **Compiler time:** forgetting macro code runs at compile time
- **Compiled names:** assuming raw Lua sees original Fennel local names

## More detail

See `references/fennel-language.md` for Lua-to-Fennel rewrites, everyday syntax, destructuring, debugging, and a compact module example
