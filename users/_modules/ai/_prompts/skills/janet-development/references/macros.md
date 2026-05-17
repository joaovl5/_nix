# Janet Macros Reference

## Upstream refs

- [Macros](https://janet-lang.org/1.40.1/docs/macros.html)
- [Special Forms](https://janet-lang.org/1.40.1/docs/specials.html)
- [Syntax and the Parser](https://janet-lang.org/1.40.1/docs/syntax.html)
- [Functions](https://janet-lang.org/1.40.1/docs/functions.html)

## When to use a macro

- **Default rule:** prefer a function if the transformation can happen at
  runtime
- **Macro use:** reach for a macro when you need compile-time AST rewriting or
  new syntax
- **Input shape:** macro arguments are code forms, not evaluated values
- **Expansion:** the compiler expands macros before it compiles the result

## Quasiquote toolkit

- **Quote:** `'x` or `(quote x)` produces literal code
- **Quasiquote:** `~x` or `(quasiquote x)` lets you inject values into
  template code
- **Unquote:** `,x` evaluates `x` and inserts the result
- **Splice:** `;x` inserts multiple forms into a call or constructor, and
  `,;x` splices inside quasiquote
- **Body forwarding:** use `,;body` when the macro must forward several body
  forms into another form

## Hygiene and capture

- **Not hygienic:** Janet macros do not automatically protect introduced names
- **Capture bugs:** reusing a caller symbol inside the macro can shadow or
  capture unexpectedly
- **Fix:** use `gensym` or `with-syms` for introduced locals
- **Scope control:** use `upscope` only when the macro really needs to emit
  bindings into the caller's scope

## Expansion and debugging

- **`macex1`:** expands one macro step
- **`macex`:** expands until no macros remain
- **Habit:** inspect the expansion before debugging runtime behavior that
  looks magical
- **Signal:** if the expansion is unreadable, the macro is probably doing too
  much

## Common patterns

- **Named macros:** `defmacro` is the usual wrapper
- **Small transforms:** keep a macro focused on one syntax shape
- **Readable output:** make the expansion explicit and boring
- **Single evaluation:** if a macro duplicates an argument, make sure the
  argument is safe to evaluate twice

## Example

- `defmacro unless [test & body] ~(if (not ,test) (do ,;body))`

This is small, uses quasiquote and splicing directly, and keeps its output
easy to inspect with `macex1`
