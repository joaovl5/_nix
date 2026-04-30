# Repository Agent Guide

## Scope

- Only work on code explicitly requested by the user.

## Special Instructions

- When altering the `globals/` directory, it's necessary to run `nix flake update globals` to update `flake.lock` with the new info.

## Helpful Tooling

- Searching nix and home-manager options
  - `optnix -n -s nx <query>` - list of options if fuzzy search, more details if you give exact option name
  - switch `-s nx` with `-s hm` for searching home-manager options
  - these options also search declared options (some new ones may be missing if a system rebuild is pending)
- Searching packages
  - `nh search <query>`

## Repo-local skills

- When adding, editing, reviewing, or debugging NixOS VM/integration tests under `tests/`, read `.agents/skills/writing-nixos-tests/SKILL.md` first.

## Required checks after changes

In this order:

- `nix fmt` - basic formatting, runs `treefmt` under the hood
- `prek` - precommit hook has linters included
  - prek only operates on git staged files, so you have to run `git add .` for `prek` to correctly check
- IN SOME CASES (see more below): `nix flake check --all-systems` (after the other checks pass)
  - **only** run `nix flake check` when nix code has been touched.
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
