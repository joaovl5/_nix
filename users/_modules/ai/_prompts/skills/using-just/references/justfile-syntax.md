# Justfile syntax reference

## Primary upstream references

- **Manual:** <https://just.systems/man/en/>
- **Quick start:** <https://just.systems/man/en/quick-start.html>
- **Variables:** <https://just.systems/man/en/variables-and-assignments.html>
- **Expressions and substitutions:**
  <https://just.systems/man/en/expressions-and-substitutions.html>
- **Strings:** <https://just.systems/man/en/strings.html>
- **Recipe parameters:** <https://just.systems/man/en/recipe-parameters.html>
- **Dependencies:** <https://just.systems/man/en/dependencies.html>
- **Shebang recipes:** <https://just.systems/man/en/shebang-recipes.html>
- **Script recipes:** <https://just.systems/man/en/script-recipes.html>
- **Settings:** <https://just.systems/man/en/settings.html>
- **Private recipes:** <https://just.systems/man/en/private-recipes.html>
- **Quiet recipes:** <https://just.systems/man/en/quiet-recipes.html>
- **Formatting and dumping:**
  <https://just.systems/man/en/formatting-and-dumping-justfiles.html>
- **Grammar:** <https://just.systems/man/en/grammar.html> and
  <https://github.com/casey/just/blob/master/GRAMMAR.md>

## Mental model

- **Just layer:** recipes, dependencies, variables, settings, strings,
  attributes, and `{{...}}` substitutions
- **Shell layer:** normal linewise recipe commands after Just interpolation;
  default shell is `sh -cu` unless configured
- **Tool layer:** arguments consumed by the command itself, such as `nix run`
  flake refs

- **Glob expansion:** Just does not expand `*` or `**`; the configured shell
  does. Default `sh` lacks fish/zsh-style recursive `**`
When behavior is surprising, locate the layer first

## Core forms

```just
# variables use :=
name := "world"

# command fragments can remove repetition
nix_raw := "nix --quiet --log-format raw"
rumdl := nix_raw + " run '.#rumdl' --"

# first recipe is the default when `just` has no recipe argument
hello target=name:
    echo 'hello {{ target }}'

# dependencies run before the dependent recipe
check: fmt lint
    {{ rumdl }} check --no-cache --silent

fmt:
    just --fmt

lint:
    just --summary
```

## Comments and `#`

- **Top-level comments:** unindented lines beginning with `#` are Just
  comments
- **Recipe lines:** indented recipe text is passed to the shell after Just
  interpolation; recipe lines beginning with `#` can be ignored with
  `set ignore-comments`, but the default is `false`
- **Shell comments:** in `sh`, `#` starts a comment when it begins a shell
  word, usually after whitespace; it is literal inside another word or quotes
- **Nix flakes:** prefer quoting flake refs so both humans and shells read
  them clearly

```just
run:
    nix run '.#pkg'     # good: quoted flake ref
    nix run .#pkg       # also one shell word in sh
    nix run . #pkg      # bad: #pkg is a shell comment
```

## Variables, strings, and interpolation

- **Assignments:** `name := expression`; inspect with `just --evaluate`
- **String fragments:** use variables for repeated command prefixes when the
  expanded command still reads clearly in `just --dry-run`
- **Strings:** single-quoted strings are raw; double-quoted strings process
  escapes such as `\n`, `\t`, `\"`, and `\\`
- **Substitutions:** `{{expression}}` inserts text into recipe lines before
  the shell parses them
- **Literal braces:** use `{{{{` for a literal `{{` inside a recipe line
- **Formatter style:** canonical `just --fmt` writes substitutions as
  `{{ name }}`; prefer that spacing in edited recipes
- **Path join:** `a / b` joins with `/`; it does not normalize duplicate
  slashes

## Parameters and argument safety

```just
build target mode='debug':
    cargo build --profile '{{ mode }}' -p '{{ target }}'

# export one parameter to the shell environment
show $name:
    printf '%s\n' "$name"

# positional arguments can avoid splitting for arbitrary values
set positional-arguments
open file:
    xdg-open "$1"
```

Important pitfall: command-line quotes are consumed before Just receives the
argument. If `{{file}}` expands to `some path`, the shell sees two words
unless you quote the interpolation or use exported/positional parameters

## Dependencies

- **Prior dependencies:** `test: build` runs `build` before `test`
- **Subsequent dependencies:** `deploy: build && notify` runs `notify` after
  `deploy`
- **One run per arguments:** the same recipe with the same arguments runs once
  per Just invocation, even if multiple dependents need it
- **Parameterized dependencies:** pass arguments with parentheses:
  `default: (build "main")`

Avoid recursive `just other` calls unless a separate invocation is intended;
assignments are recalculated, dependencies can run again, and parent arguments
are not automatically propagated

## Recipe visibility and output

- **Quiet line:** prefix a recipe line with `@` to suppress echoing that line
- **Quiet recipe:** prefix recipe name with `@` to invert line-level quieting
- **Global quiet:** `set quiet` quiets all recipes unless overridden
- **Private helpers:** names starting with `_` are hidden from `just --list`
  and `just --summary`; `[private]` can hide a recipe without renaming it

## Linewise, shebang, and script recipes

- **Linewise recipes:** default mode; each command line is run by the
  configured shell, usually as a separate shell command
- **Shebang recipes:** body starts with `#!`; Just writes the body to a
  temporary file and executes it with the shebang interpreter
- **Script recipes:** `[script(COMMAND)]` writes the evaluated body to disk
  and runs it with `COMMAND`; empty `[script]` uses `set script-interpreter`,
  not `set shell`
- **Shell-specific scripts:** use `[script("fish")]` or another explicit
  interpreter when a multiline recipe needs that shell's globbing or syntax,
  instead of forcing everything through `fish -c '...'`

Use `[script]` or shebang recipes when state must persist across lines, when
using another language, or when complex shell quoting would obscure intent

## Settings to know

```just
set shell := ["bash", "-cu"]
set script-interpreter := ["sh", "-eu"]
set positional-arguments
set quiet
set ignore-comments
```

Set these only when the whole file benefits. Prefer local recipe structure
over broad settings when only one recipe needs special behavior

## Quick validation commands

```sh
# parse and formatting check without rewriting
just --fmt --check -f justfile

# list visible recipe names
just --summary -f justfile

# preview a recipe without running commands
just --dry-run -f justfile <recipe>

# inspect variables or canonical parsed output
just --evaluate -f justfile
just --dump -f justfile
just --dump --dump-format json -f justfile
```

If a justfile is intentionally named `Justfile` or `.justfile`, replace the
`-f justfile` argument with that path
