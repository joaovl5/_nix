---
name: fennel-development
description: Use when reading, writing, or reviewing Fennel code; covers syntax, semantics, macros, Lua interop, fennel-ls/flsproject workflow, and common mistakes.
---

Use this for Fennel language work and repo Fennel tooling such as `flsproject.fnl`. For repo Neovim maintenance flow, also load `neovim-configuration`.

Primary refs: <https://fennel-lang.org/tutorial>, <https://fennel-lang.org/reference>, <https://fennel-lang.org/macros>, <https://fennel-lang.org/lua-primer>.

## Mental model

- Fennel compiles to Lua; Lua runtime semantics still apply.
- `()` are calls/forms, not runtime list objects. Use `[]` for dense sequences and `{}` for tables.
- Files export their last value.
- `require` uses dotted names; embedded hosts need a Fennel loader or precompiled Lua.
- `include` bundles module code at compile time, emits a runtime `require`, and loads that bundled module on demand.

## Macros

- Use macros only for compile-time transformation; prefer functions for runtime helpers.
- Macro inputs are code forms, not evaluated values.
- Quote AST templates with backtick, unquote with `,`, and splice with `,@`.
- Introduced locals should usually use `#` gensyms.
- Shared macros live in macro modules and load with `import-macros`.
- Macro modules run in compiler scope, not runtime.
- General compiler-scope helpers include `list`, `sym`, `gensym`, and `view`.
- `macroexpand` and `in-scope?` are macro-only helpers; do not call them from arbitrary `eval-compiler` code.

## Repo fennel-ls / flsproject rules

- `users/_modules/neovim/config/flsproject.fnl` is the source of truth; `flsproject.lua` is generated.
- Never hand-edit `flsproject.lua`; edit `flsproject.fnl` and regenerate.
- `flsproject.fnl` controls Lua version, Fennel path, macro path, Neovim library hints, and extra globals such as `vim`, `MiniFiles`, `MiniExtra`, `MiniIcons`, `MiniMisc`, and `Snacks`.
- `users/_modules/neovim/config/fnl/lib/init-macros.fnl` must keep `;; fennel-ls: macro-file` as the exact first line.
- This repo roots `fennel-ls` by searching upward for `flsproject.fnl`; moving that file changes project rooting.
- For broader maintenance and recompilation, load `neovim-configuration`.

## Common mistakes

- Treating `(...)` as runtime arrays.
- Forgetting `fn` ignores extra args and fills missing args with `nil`; use `lambda` when missing required args should fail loudly.
- Treating `...` as a table.
- Expecting table equality to be structural; Lua tables compare by identity.
- Using `length` or `ipairs` on sparse sequences.
- Overusing macros for ordinary helpers.
- Forgetting macro code runs at compile time.
- Assuming raw Lua sees original Fennel local names; it sees compiled Lua names.

## More detail

See `references/fennel-language.md` for Lua-to-Fennel rewrites, everyday syntax, destructuring, debugging, and a compact module example.
