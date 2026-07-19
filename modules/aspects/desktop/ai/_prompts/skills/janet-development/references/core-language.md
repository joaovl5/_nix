# Janet Core Language Reference

## Upstream refs

- [Syntax and the Parser](https://janet-lang.org/1.40.1/docs/syntax.html)
- [Bindings (def and var)](https://janet-lang.org/1.40.1/docs/bindings.html)
- [Flow](https://janet-lang.org/1.40.1/docs/flow.html)
- [Functions](https://janet-lang.org/1.40.1/docs/functions.html)
- [Looping](https://janet-lang.org/1.40.1/docs/loop.html)
- [Comparison Operators](https://janet-lang.org/1.40.1/docs/comparison.html)
- [Special Forms](https://janet-lang.org/1.40.1/docs/specials.html)
- [Error Handling](https://janet-lang.org/1.40.1/docs/fibers/error_handling.html)
- [Data Structures](https://janet-lang.org/1.40.1/docs/data_structures/index.html)

## Parse model

- **Code as data:** Janet source is parsed into Janet values; there
  are no reader macros
- **Calls vs literals:** `()` is the normal call tuple, `[]` marks a
  tuple literal, and `@[]`/`@{}` create mutable arrays and tables
- **Buffers:** prefix string or long-string syntax with `@` to get a
  mutable buffer
- **Text forms:** strings are byte strings, long strings use
  backquotes, and comments start with `#`
- **Prefix forms:** `'x`, `~x`, `,x`, `;x`, and `,;x` are the common
  shorthand forms for quote, quasiquote, unquote, splice, and
  unquote-splice
- **Keywords and symbols:** keywords start with `:`, symbols name
  bindings, and module-qualified names usually use `/`

## Values and mutability

- **Truthiness:** only `nil` and `false` are falsey; `0` and `@[]` are
  truthy
- **Numbers:** Janet numbers are IEEE-754 doubles
- **Mutable containers:** arrays, tables, and buffers mutate; tuples,
  structs, strings, symbols, and keywords do not
- **Identity vs contents:** `=` checks identity for mutable values, so
  use `deep=` when you want structural comparison
- **Inequality:** `not=` is the Janet inequality operator

## Bindings and scope

- **`def`:** immutable lexical binding
- **`var`:** mutable lexical binding
- **`set`:** updates a var or a collection slot
- **`let`:** preferred local-binding form for small scopes
- **`do` / `fn`:** both introduce scopes; `do` sequences forms, `fn`
  builds closures
- **Destructuring:** `def`, `let`, and function arguments can
  destructure arrays, tuples, tables, and structs
- **Metadata:** top-level `def` and `var` can carry `:private` and
  docstrings

## Functions and flow

- **Return value:** `fn` and `defn` return the last body form
- **Arity:** use `&` to ignore extras, `&opt` for optional tail args,
  `&keys` for keyword packs, and `&named` for named arguments
- **Short lambdas:** `|` is `short-fn`, and `$`, `$0`, `$1`, and `$&`
  refer to arguments
- **Branching:** `if` is lazy and only false on `nil` or `false`;
  `when`, `cond`, and `case` are the common higher-level forms
- **Looping:** `while` is the primitive loop; `for`, `loop`, and
  `each` cover the common iteration cases
- **Early exit:** `break` exits the innermost loop or returns from a
  function
- **Splicing:** `;` often removes the need for `apply`

## Errors and fibers

- **Errors:** `error` raises, `try` handles the common case, and
  `protect` converts caught failures into values
- **Fibers:** error handling is fiber-based; `fiber/status` and
  `fiber/last-value` tell you what happened
- **Rule of thumb:** prefer ordinary flow first, then fibers when you
  need coroutine-style control or error isolation

## Common mistakes

- **`!=`:** not Janet syntax; use `not=`
- **Identity vs value:** using `=` on mutable containers when you
  wanted `deep=`
- **`def` vs `var`:** using `def` for state that needs mutation
- **`[]` vs `@[]`:** forgetting that `[]` is a literal tuple, not a
  mutable array
- **Falsey assumptions:** treating `0` as false or assuming `@[]` is
  false
- **`apply`:** reaching for `apply` before checking whether `;` splice
  or `short-fn` fits better
