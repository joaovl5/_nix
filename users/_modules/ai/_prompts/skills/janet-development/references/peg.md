# Janet PEG Reference

## Upstream refs

- [Parsing Expression Grammars](https://janet-lang.org/1.40.1/docs/peg.html)
- [PEG Module](https://janet-lang.org/1.40.1/api/peg.html)

## Mental model

- **Why PEGs:** they are Janet's regex killer, but with recursion and structured captures
- **Input model:** PEGs match bytes, not grapheme clusters
- **Match model:** matching is anchored; search and replacement are built from PEG idioms, not regex flags
- **Reuse:** compile once with `peg/compile` when the same pattern will run many times

## Primitive patterns

- **Strings:** a literal string matches itself
- **Integers:** a positive integer matches that many bytes, `0` matches the empty string, and a negative integer can anchor near the end of input
- **Ranges and sets:** `range` matches byte ranges and `set` matches any byte from a set
- **Literals:** `true` always matches and `false` never matches

## Combinators

- **Choice:** `choice` or `+` tries branches in order and stops at the first success
- **Sequence:** `sequence` or `*` matches forms in order
- **Repetition:** `any`, `some`, `between`, `at-least`, `at-most`, `repeat`
- **Conditions:** `if`, `if-not`, `not`/`!`, and `look`/`>` are the common guard forms
- **Windows:** `to`, `thru`, `opt`/`?`, `backmatch`, and `sub` handle the common scanning cases
- **Order matters:** PEGs are greedy and do not backtrack like regex, except through choice

## Captures

- **Basic capture:** `capture`, `<-`, and `'`
- **Grouping and replacement:** `group`, `replace`, and `/`
- **Position and metadata:** `constant`, `argument`, `position`/`$`, `column`, and `line`
- **Text accumulation:** `accumulate`/`%` builds strings from captures
- **Tagged control:** `cmt`, `backref`/`->`, `unref`, `error`, `drop`, `only-tags`, and `nth`
- **Binary numbers:** `uint`, `uint-be`, `int`, `int-be`, `lenprefix`, and `number`

## Grammars

- **Shape:** a grammar is a struct of keyword-keyed rules
- **Entry rule:** every grammar needs `:main`
- **Recursion:** rules can refer to each other recursively
- **Limit:** recursion can overflow the stack on large or badly written inputs

## Idioms

- **Search grammar:** wrap the needle in an `any` search pattern with a `position` capture
- **Replacement grammar:** use `accumulate` or `replace` when you want the matched text transformed
- **Fast reuse:** compile reusable PEGs instead of reparsing the source pattern every time

## Common mistakes

- **Forgetting `:main`:** a grammar without it will not match as expected
- **Regex habits:** expecting backtracking or capture semantics that PEGs do not have
- **Branch order:** putting the broad branch before the narrow branch in `choice`
- **Search confusion:** treating `peg/match` like an unanchored regex search
