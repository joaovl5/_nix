---
name: using-just
description: Use when editing, reviewing, or debugging justfiles or Just recipes, including recipe syntax, parameters, interpolation, comments, Nix flake refs with #, shell settings, and just CLI validation
---

Use this for Just command-runner files such as `justfile`, `Justfile`,
and `.justfile`. Prefer project-local instructions when they conflict
with this user-wide guide

## Core principle

Just parses the orchestration layer; the configured shell parses
recipe lines. Keep that boundary explicit, especially around quoting,
`{{...}}`, `$vars`, and `#`

## First moves

- **Find the active file:** check whether the project uses `justfile`,
  `Justfile`, or `.justfile`; `just` searches upward from the working
  directory
- **Read nearby recipes:** preserve existing indentation, naming,
  quieting, and dependency style before adding new conventions
- **Load syntax detail:** use `references/justfile-syntax.md` before
  touching parameters, dependencies, comments, scripts, shebangs, or
  settings
- **Check parse boundaries:** decide whether a problem belongs to Just
  syntax, shell syntax, or the called tool before editing

## Editing rules

- **Keep recipes small:** prefer one clear orchestration task per
  recipe and use private helpers for shared setup
- **Use variables for repeated fragments:** define shared command
  prefixes with `:=` and reuse them with `{{ name }}` when it keeps
  recipes clearer
- **Use dependencies first:** put setup recipes in dependencies
  instead of recursively calling `just` mid-recipe unless a fresh
  invocation is intended
- **Quote shell data:** quote `{{...}}` substitutions or use
  exported/positional parameters when values may contain spaces or
  shell metacharacters
- **Quote Nix refs:** write flake refs as `'.#pkg'` or `'.#check'` for
  clarity; `.#pkg` is one shell word, while `. #comment` is not
- **Choose script mode deliberately:** use linewise recipes for simple
  commands; use `[script]` or shebang recipes when one shell process
  or a non-shell language is needed
- **Quiet intentionally:** use `@` for noise control, not to hide
  important commands while debugging failures

## References

Load only when needed:

- **Justfile syntax:** `references/justfile-syntax.md` covers core
  syntax, common pitfalls, quick validation commands, and upstream
  manual links

## Validation

Use quick checks first, then follow project-local instructions if
broader checks are needed

```sh
just --fmt --check -f justfile
just --summary -f justfile
just --dry-run -f justfile <recipe>
```

For variables and parse inspection:

```sh
just --evaluate -f justfile
just --dump -f justfile
```

## Common mistakes

- **Wrong parser:** treating shell syntax errors as Just parser
  errors, or the reverse
- **Hash confusion:** assuming `nix run .#pkg` isn't a Just comment;
  quote it as `nix run '.#pkg'` and avoid whitespace before `#`
- **Glob assumptions:** remembering that `*` and `**` expansion is
  shell behavior, not Just behavior; use the right shell explicitly
  when needed
- **Split arguments:** assuming CLI quotes survive `{{arg}}`;
  substitutions are text inserted before the shell parses the line
- **Hidden helpers:** forgetting `_helper` or `[private]` when a
  support recipe should not show in `just --list`
- **Recursive overuse:** calling `just other` inside a recipe when a
  dependency would preserve one invocation's dependency and argument
  semantics
