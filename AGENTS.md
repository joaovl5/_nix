# Repository Agent Guide

## Scope
- Only work on code explicitly requested by the user.

## Required checks after changes
- `statix check -o errfmt`
- `deadnix`
- `nix flake check --all-systems` (after the other checks pass)
  - `nix flake check` will warn about unknown flake outputs `deploy` and `pkgs`; this is expected.

## Instruction updates
- If any tool usage, procedures, or code guidelines change, suggest updating this file to reflect them.
