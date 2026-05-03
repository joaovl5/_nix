# Fennel Language Reference

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

## Everyday syntax

### Data and literals

- `;` starts a line comment.
- Strings use `"..."`.
- Keywords like `:key` are string shorthand.
- Map table: `{:key value :other 2}`.
- Sequence table: `[1 2 3]`.
- Dynamic lookup: `(. tbl key)`.
- Known string key: `tbl.key`.
- Nil-safe lookup: `(?. tbl :key)` when available in your Fennel version.
- Mutation: `(set tbl.key 3)` or `(tset tbl key value)`.

### Functions and binding

- Named function: `(fn name [a b] ... last-value)`.
- Anonymous function: `(fn [x] (+ x 1))`.
- `fn` ignores extra args and fills missing args with `nil`.
- `lambda` fails loudly when required args are `nil`.
- Use `let` for short scopes, `local` for stable bindings, and `var` only when rebinding is required.
- Bindings are immutable; referenced tables are not.

### Control flow and iteration

- `if` is an expression.
- `when` is side-effecting with no `else`.
- `do` groups forms and returns the last.
- `each` consumes Lua iterators.
- `for` handles numeric ranges.
- `while` handles loops.
- `icollect` builds sequences.
- `collect` builds key/value tables.
- `accumulate`, `fcollect`, and `faccumulate` cover tighter loop cases.

### Destructuring and values

- Sequence destructuring: `[a b & rest]`.
- Table destructuring: `{:x x :y y}`.
- `&as` keeps the original value too.
- Only `nil` and `false` are falsey.
- `or` is a fallback operator, not a nil-only operator.
- `...` is not a table. Use `[ ... ]`, `table.pack`, `values`, `pick-values`, `select`, or `table.unpack` when you need exact multivalue control.

## Interop and debugging

- Lua APIs call directly from Fennel.
- `lua` emits raw Lua when Fennel syntax is not enough. Use it sparingly.
- `(print tbl)` usually shows table identity only; use `fennel.view` when available or the host's inspector.
- Use `macrodebug` first for macro expansion issues.

## Compact module example

```fennel
(local builtin (require :telescope.builtin))

(fn pick [opts]
  (builtin.find_files (or opts {:hidden true})))

{:pick pick}
```

Why this is idiomatic:

- Top-level `local` for a reused module handle.
- Plain `fn`; no macro needed.
- Final expression returns the module table.
- Plain field call, not `:` method syntax.
