# Repository Agent Guide

## Scope

- Only work on code explicitly requested by the user.

## Special Instructions

- **npins/flake-compat:**
  - `npins/sources.json` is the source of truth for pinned external inputs.
  - `inputs.nix` adapts those pins through `flake-compat` into the flake-shaped
    `inputs` set consumed by the repo.
  - `flake.nix` is a thin shim over `default.nix`; keep it thin and do not
    treat it as the input source of truth.
  - `mysecrets` updates should use `npins update mysecrets` and stage
    `npins/sources.json`.
- When creating or maintaining repo-local skills under `.agents/skills/`, use
  `.agents/skills/skill-authoring/SKILL.md` as the authoritative workflow.
  Prefer it over generic skill-writing guidance when they conflict.

## Helpful Tooling

- Searching nix and home-manager options
  - `optnix -n -s nx <query>` - list of options if fuzzy search, more details
    if you give exact option name
  - switch `-s nx` with `-s hm` for searching home-manager options
  - these options also search declared options (some new ones may be missing
    if a system rebuild is pending)
- Searching packages
  - `nh search <query>`

## Repo-local skills

- When adding, editing, reviewing, or debugging NixOS VM/integration tests
  under `tests/`, read `.agents/skills/writing-nixos-tests/SKILL.md` first.

## Required checks after changes

In this order:

- Run `npins verify` when `npins/sources.json`, `npins/default.nix`, or
  `inputs.nix` changes.
- `nix fmt` - basic formatting, runs `treefmt` through the thin flake shim.
- `prek` - precommit hook has linters included.
  - `prek` only operates on git staged files, so stage the exact intended
    files before running it.
- IN SOME CASES (see more below): `nix flake check --all-systems` (after the
  other checks pass).
  - **only** run `nix flake check` when Nix code has been touched.
  - `nix flake check` will warn about unknown flake outputs `deploy` and
    `pkgs`; this is expected.
  - If `--all-systems` is blocked by local builder/binfmt constraints, run
    local `nix flake check`, run the relevant targeted host/package/check
    matrix, and document the blocker.

## Instruction updates

- If any tool usage, procedures, or code guidelines change, **suggest**
  updating this file to reflect them.

## Nomenclature

- Use `snake_case` for variables and functions.
- Meta modules (helpers that do not directly alter config) should be prefixed
  with an underscore (e.g., `_modules/_mylib.nix`).
- Variables representing types (submodules) should be in PascalCase.

## Documentations

- Documentation is available at `README.md` files across directories.
- These files should not be written to unless explicitly stated, you may
  **suggest** changes.
