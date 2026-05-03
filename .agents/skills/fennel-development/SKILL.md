---
name: fennel-development
description: Use when reading, writing, or reviewing Fennel code; covers syntax, semantics, macros, Lua interop, fennel-ls/flsproject workflow, and common mistakes.
---

# Fennel Development

Primary refs:

- <https://fennel-lang.org/tutorial>
- <https://fennel-lang.org/reference>
- <https://fennel-lang.org/macros>
- <https://fennel-lang.org/lua-primer>

Use this for language questions and repo Fennel tooling such as `flsproject.fnl`.
For repo Neovim maintenance flow, also load `neovim-configuration`.

## Mental model

- Compile target
  - Fennel compiles to Lua.
  - `()` are syntax for calls/forms, not runtime list objects.
  - `{}` and `[]` become normal Lua tables.
- Compile time vs runtime
  - Macros run at compile time and return Fennel AST.
  - Macro modules are not normal runtime modules.
  - Lua semantics still govern runtime behavior.

## Common Lua -> Fennel rewrites

- Import a module
  - Lua: `local mod = require("x.y")`
  - Fennel: `(local mod (require :x.y))`
- Return a value
  - Lua: `return foo(bar)`
  - Fennel: final expression `(foo bar)`
- Export a module table
  - Lua: `local M = {}; function M.pick(opts) ... end; return M`
  - Fennel: define helpers, then end with `{:pick pick}` or bare `M`
- Call a field vs a method
  - Lua: `obj.method(a, b)` -> Fennel: `(obj.method a b)`
  - Lua: `obj:method(a, b)` -> Fennel: `(obj:method a b)`

## Everyday Fennel

### Data and literals

- Comments
  - `;` starts a line comment.
- Strings and keywords
  - Strings use `"..."`.
  - Keywords like `:key` are string shorthand.
- Tables
  - Map style: `{:key value :other 2}`
  - Sequence style: `[1 2 3]`
- Lookup and mutation
  - Dynamic lookup: `(. tbl key)`
  - Known string key: `tbl.key`
  - Nil-safe lookup: `(?. tbl :key)` when available in your Fennel version
  - Mutation: `(set tbl.key 3)` or `(tset tbl key value)`

### Functions and binding

- Functions
  - Named: `(fn name [a b] ... last-value)`
  - Anonymous: `(fn [x] (+ x 1))`
- Arity
  - `fn` ignores extra args and fills missing args with `nil`.
  - `lambda` fails loudly when required args are `nil`.
- Locals
  - `let` for short scopes.
  - `local` for stable bindings.
  - `var` only when rebinding is required.
  - Bindings are immutable; referenced tables are not.

### Control flow and iteration

- Conditionals
  - `if` is an expression.
  - `when` is side-effecting with no `else`.
  - `do` groups forms and returns the last.
- Iteration
  - `each` for Lua iterators.
  - `for` for numeric ranges.
  - `while` for loops.
- Collection macros
  - `icollect` builds sequences.
  - `collect` builds key/value tables.
  - `accumulate`, `fcollect`, and `faccumulate` cover tighter loop cases.

### Destructuring and values

- Destructuring
  - Sequences: `[a b & rest]`
  - Tables: `{:x x :y y}`
  - `&as` keeps the original value too.
- Multi-values
  - `...` is not a table.
  - Use `[ ... ]`, `table.pack`, `values`, `pick-values`, `select`, or `table.unpack` when you need exact control.
- Truthiness
  - Only `nil` and `false` are falsey.
  - `or` is a fallback operator, not a nil-only operator.

## Modules and interop

- Modules
  - A file exports its last value.
  - `require` uses dotted names, not slashes.
  - `include` is compile-time inclusion, not runtime loading.
- Host interop
  - Lua APIs call directly from Fennel.
  - In embedded hosts, `require` only loads `.fnl` if the host installs a Fennel loader or precompiles to Lua.
- Raw Lua escape hatch
  - `lua` emits raw Lua when Fennel syntax is not enough.
  - Use it sparingly.
  - Raw Lua sees compiled local names, not original Fennel spelling.

## Macros

### When to use them

- Use a macro only for compile-time transformation.
- Do not use macros for ordinary runtime helpers.
- If a function works, prefer the function.

### Core rules

- Macro inputs are code forms, not evaluated values.
- Quote AST templates with backtick.
- Unquote with `,`.
- Prefer quoted templates over manual `list` / `sym` building.
- Introduced locals should usually use `#` gensyms.

### Macro modules

- Shared macros live in macro modules and load through `import-macros`.
- Macro modules run in compiler scope, not runtime.
- Macro modules are searched as `.fnl` or `.fnlm`.
- If an expansion needs another module, require it inside the expansion.

### Compiler scope

- Compiler code can use helpers like `list`, `sym`, `gensym`, `macroexpand`, and `view`.
- Compiler scope is sandboxed for convenience, not security.
- Keep macro code deterministic when possible.

## fennel-ls / flsproject in this repo

- Source of truth
  - `users/_modules/neovim/config/flsproject.fnl` is the fennel-ls project file.
  - `users/_modules/neovim/config/flsproject.lua` is generated from it.
  - Never hand-edit `flsproject.lua`; edit `flsproject.fnl` and regenerate.
- What `flsproject.fnl` controls
  - Lua version.
  - Fennel path.
  - Macro path.
  - Neovim library hints.
  - Extra globals such as `vim`, `Mini*`, and `Snacks`.
- Macro discovery
  - `users/_modules/neovim/config/fnl/lib/init-macros.fnl` is tagged with `;; fennel-ls: macro-file`.
  - If macro paths or macro files change, keep `flsproject.fnl` aligned with the actual tree.
- Rooting
  - This repo's Neovim LSP setup roots `fennel-ls` by searching upward for `flsproject.fnl`.
  - Moving or renaming that file changes project rooting.
- Local procedure
  - Change `flsproject.fnl`.
  - Regenerate `flsproject.lua`.
  - If the change affects macro paths or compile behavior, recompile the Neovim Fennel tree too.
  - Keep the docset-fetch comment in `flsproject.fnl` unless you are intentionally changing that workflow.
- Runtime expectation
  - `fennel-ls` is expected on `PATH` by the repo's Neovim config.
- Compile flow
  - Live Neovim: open a Fennel buffer in `users/_modules/neovim/config/` and run `:NfnlCompileAllFiles`.
  - Headless from the repo root: `.agents/skills/neovim-configuration/scripts/recompile-nfnl.py`
  - To inspect orphans without deleting them: `.agents/skills/neovim-configuration/scripts/recompile-nfnl.py --keep-orphans`
  - The wrapper opens `flsproject.fnl` first because nfnl commands are buffer-local, and `.nfnl.fnl` must already have been trusted once.
  - For the broader config-maintenance map, see `neovim-configuration`.

## Debugging and inspection

- Table display
  - `(print tbl)` usually shows identity only.
  - Use `fennel.view` when available.
  - Otherwise use the host's inspector.
- Macro debugging
  - `macrodebug` is the first tool for expansion issues.

## Common mistakes

- Lists vs arrays
  - `(...)` are syntax, not runtime arrays; use `[]` for dense sequences.
- Silent arity
  - `fn` does not reject wrong arity; use `lambda` when you need loud failures.
- Varargs
  - `...` is not a table.
- Table equality
  - Tables compare by identity, not structural contents.
- Sparse sequences
  - `length` and `ipairs` are unreliable with `nil` holes.
- Overusing macros
  - Use functions unless you truly need compile-time transformation.
- Unhygienic macro locals
  - Introduced locals should usually use `#` gensyms.
- Runtime vs compiler scope
  - Macro code runs at compile time, not runtime.
- Raw Lua locals
  - `lua` sees compiled Lua names, not original Fennel names.
- Early return assumptions
  - Ordinary Fennel is expression-oriented; structure code so the last form is the result.

## Compact example

```fennel
(local builtin (require :telescope.builtin))

(fn pick [opts]
  (builtin.find_files (or opts {:hidden true})))

{:pick pick}
```

Why this is idiomatic:

- Top-level `local` for a reused module handle.
- Plain `fn`; no macro needed.
- Final expression returns the value.
- Final table exports the module.
- Plain field call, not `:` method syntax.
