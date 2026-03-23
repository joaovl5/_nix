# ast-grep atomic rules

Atomic rules match a single syntax node. Types: `pattern`, `kind`, `regex`, `nthChild`, `range`.

## pattern

- Matches one syntax node by pattern syntax.
- String patterns are parsed/matched as a whole node by default.
- Example:

```yaml
rule:
  pattern: console.log($GREETING)
```

Matches `console.log('Hello World')`.

### pattern object

Use when plain pattern text is invalid, incomplete, or ambiguous without context.

Fields:
- `context` (required): surrounding code used for parsing.
- `selector` (optional): sub-node kind inside `context` to use as actual pattern target.
- `strictness` (optional): match strategy.

Example for JS class field:

```yaml
pattern:
  selector: field_definition
  context: class A { $FIELD = $INIT }
```

How it works:
1. Parse `context` as full code.
2. Select `selector` node from parsed tree.
3. Match that selected node as the pattern.

This makes `$FIELD = $INIT` parse as `field_definition` instead of `assignment_expression`.

### strictness

Default is `smart`.

- `cst`: exactest; pattern and target nodes all match, nothing skipped.
- `smart`: all pattern nodes must match; unnamed target nodes may be skipped.
- `ast`: only named AST nodes on both sides matter; unnamed nodes skipped.
- `relaxed`: named AST nodes match; comments + unnamed nodes ignored.
- `signature`: only named node kinds match; comments, unnamed nodes, and text ignored.

Example: pattern `function $A() {}` matches both normal and `async` JS functions under `smart`, because `async` is unnamed and can be skipped.

Use `strictness` only when default matching is not sufficient.

## kind

- Matches by tree-sitter node kind name, e.g. `if_statement`, `expression`, `field_definition`.
- Best when writing a valid/precise pattern is hard or ambiguous.

Example:

```yaml
rule:
  kind: field_definition
```

Matches JS class properties like:

```js
class Test {
  a = 123
}
```

Useful when:
- Syntax is ambiguous (`{}` in JS may be object or block).
- Enumerating all textual forms is impractical (e.g. all class declaration variants).
- The construct only appears in a specific context (e.g. class property definitions).

`kind + pattern` does not change pattern parsing; rules are independent. To control pattern parsing, use a pattern object with `context` + `selector`.

### ESQuery-style kind (experimental, v0.39.1+)

Example:

```yaml
rule:
  kind: call_expression > identifier
```

Matches an `identifier` that is a direct child of `call_expression`. Internally converts to relational rule `has`.

Supported selectors:
- node kind: `identifier`
- `>` direct child
- `+` next sibling
- `~` following sibling
- ` ` descendant

## regex

- Matches node text against a Rust regex.
- Prefer combining with other atomic rules so regex runs on the correct node.
- Slower than `kind`/`pattern`; cannot benefit from AST kind optimization.
- Rust regex syntax, not PCRE; no arbitrary look-ahead or backreferences.
- Supports inline flags, e.g. `(?i)apple`.

Example:

```yaml
rule:
  regex: "\\w+"
```

## nthChild

- Matches nodes by position among sibling nodes in the parent’s children list.
- Inspired by CSS `:nth-child`.
- Sibling list includes only named nodes.
- Index is 1-based, not 0-based.

Forms:

```yaml
nthChild: 3
nthChild: 2n+1
nthChild:
  position: 2n+1
  reverse: true
  ofRule:
    kind: function_declaration
```

Fields:
- `position`: number or `An+B` string.
- `reverse` (optional): count from end; default `false`.
- `ofRule` (optional): filter sibling set before indexing.

Example:

```yaml
rule:
  kind: number
  nthChild: 2
```

Matches the second number in `[1, 2, 3]`.

## range

- Matches nodes by source location.
- Useful for integrating compiler/type-checker output with ast-grep, then rewriting matched code.
- Takes `start` and `end`; each has `line` and `column`.
- `line`/`column` are 0-based, character-based.
- `start` is inclusive; `end` is exclusive.

Example:

```yaml
rule:
  range:
    start:
      line: 0
      column: 0
    end:
      line: 1
      column: 5
```

## rule-writing tips

- Each match corresponds to one AST node, so first identify the exact node you want and write the atomic rule that matches it.
- Example workflow: to find functions without return types, first target the function node itself (e.g. `kind: arrow_function`), then add filters for missing return type.
- Use sub-rules as fields to keep rules cleaner; see composite rules.
