# Fennel Language Reference

## Common Lua -> Fennel rewrites

- **Import a module:**
  - Lua: `local mod = require("x.y")`
  - Fennel: `(local mod (require :x.y))`
- **Return a value:**
  - Lua: `return foo(bar)`
  - Fennel: final expression `(foo bar)`
- **Export a module table:**
  - Lua: `local M = {}; function M.pick(opts) ... end; return M`
  - Fennel: define helpers, then end with `{:pick pick}` or bare `M`
- **Call a field vs a method:**
  - Lua: `obj.method(a, b)` -> Fennel: `(obj.method a b)`
  - Lua: `obj:method(a, b)` -> Fennel: `(obj:method a b)`

## Everyday syntax

### Data and literals

- **Comments:** `;` starts a line comment
- **Strings:** use `"..."`
- **Keywords:** `:key` is string shorthand
- **Map table:** `{:key value :other 2}`
- **Sequence table:** `[1 2 3]`
- **Dynamic lookup:** `(. tbl key)`
- **Known string key:** `tbl.key`
- **Nil-safe lookup:** `(?. tbl :key)` when your Fennel version supports it
- **Mutation:** `(set tbl.key 3)` or `(tset tbl key value)`

### Functions and binding

- **Named function:** `(fn name [a b] ... last-value)`
- **Anonymous function:** `(fn [x] (+ x 1))`
- **`fn`:** ignores extra args and fills missing args with `nil`
- **`lambda`:** fails loudly when required args are `nil`
- **Bindings:** use `let` for short scopes, `local` for stable bindings, and `var` only when rebinding is required
- **Immutability:** bindings are immutable; referenced tables are not

### Macros and compiler scope

- **Macro modules:** load shared macros with `import-macros`
- **Compiler scope:** macro modules run in compiler scope, not runtime
- **`macroexpand`:** macro-only helper; use it for macro forms, not arbitrary runtime code
- **`include`:** compile-time bundling still emits runtime loading for the included module
- **Templates:** quote AST with backtick, unquote with `,`, splice bodies with `,(unpack body)`
- **Sandbox:** compiler file IO is read-only and limited to cwd/subdirs unless sandboxing is disabled

### Control flow and iteration

- **`if`:** is an expression
- **`when`:** is side-effecting with no `else`
- **`do`:** groups forms and returns the last
- **`each`:** consumes Lua iterators
- **`for`:** handles numeric ranges
- **`while`:** handles loops
- **`icollect`:** builds sequences
- **`collect`:** builds key/value tables
- **Loop helpers:** `accumulate`, `fcollect`, and `faccumulate` cover tighter loop cases

### Destructuring and values

- **Sequence destructuring:** `[a b & rest]`
- **Table destructuring:** `{:x x :y y}`
- **`&as`:** keeps the original value too
- **Truthy rules:** only `nil` and `false` are falsey
- **`or`:** is a fallback operator, not a nil-only operator
- **Varargs:** `...` is not a table; use `[ ... ]`, `table.pack`, `values`, `pick-values`, `select`, or `table.unpack` when you need exact multivalue control

## Interop and debugging

- **Lua APIs:** call directly from Fennel
- **Raw Lua:** `lua` emits raw Lua when Fennel syntax is not enough; use it sparingly
- **Inspecting tables:** `(print tbl)` usually shows table identity only; use `fennel.view` when available or the host inspector
- **Macro debugging:** use `macrodebug` first for macro expansion issues

## Compact module example

```fennel
(local builtin (require :telescope.builtin))

(fn pick [opts]
  (builtin.find_files (or opts {:hidden true})))

{:pick pick}
```

Why this is idiomatic:

- **Module handle:** top-level `local` for a reused module handle
- **Function choice:** plain `fn`; no macro needed
- **Return value:** final expression returns the module table
- **Call style:** plain field call, not `:` method syntax
