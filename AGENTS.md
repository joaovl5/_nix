# Repository Agent Guide

## Scope

- Only work on code explicitly requested by the user.

## Required checks after changes

- `nix fmt` - basic formatting, runs `treefmt` under the hood
- `prek` - precommit hook has linters included
- `nix flake check --all-systems` (after the other checks pass)
  - `nix flake check` will warn about unknown flake outputs `deploy` and `pkgs`; this is expected.

## Instruction updates

- If any tool usage, procedures, or code guidelines change, **suggest** updating this file to reflect them.

## Nomenclature

- Use `snake_case` for variables and functions.
- Meta modules (helpers that do not directly alter config) should be prefixed with an underscore (e.g., `_modules/_mylib.nix`).
- Variables representing types (submodules) should be in PascalCase.

## Documentations

- Documentation is available at `README.md` files across directories.
- These files should not be written to unless explicitly stated, you may **suggest** changes.
