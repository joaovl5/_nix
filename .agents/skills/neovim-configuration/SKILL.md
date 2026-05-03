---
name: neovim-configuration
description: Use when editing this repo's Neovim config under users/_modules/neovim; covers source-vs-generated boundaries, the recompile wrapper, and common maintenance pitfalls.
---

# Neovim Configuration

Use this when editing `users/_modules/neovim/`.
For Fennel syntax, macros, and `flsproject` / fennel-ls rules, also load `fennel-development`.

Below, paths are relative to `users/_modules/neovim/`.

## First rule

- Never edit generated Lua.
  - `config/lua/**`
  - `config/flsproject.lua`
  - Edit the Fennel source instead, then recompile.

## Where changes go

- Plugin and editor behavior
  - `config/fnl/**` is the source of truth.
  - Plugin specs and plugin-local behavior usually live in `config/fnl/plugins/**`.
  - Core editor settings usually live in `config/fnl/options.fnl` and `config/fnl/keymaps.fnl`.
- Bootstrap and plugin discovery
  - `config/local.lua` is the real runtime bootstrap.
  - It sets up lazy.nvim and nfnl.
  - It scans `config/fnl/plugins` to depth `3`.
- Nix wiring
  - `default.nix` controls packages, runtimepath setup, and `_G.plugin_dirs`.
- Tree-sitter queries
  - `config/queries/**` and `config/after/queries/**` are direct-edit `.scm` files.
  - They do not go through nfnl.
- FLS project metadata
  - `config/flsproject.fnl` is the source of truth.
  - Detailed `flsproject` / fennel-ls rules live in `fennel-development`.

## Recompile workflow

- Preferred wrapper
  - Run `.agents/skills/neovim-configuration/scripts/recompile-nfnl.py` from the repo root.
  - Its default anchor buffer is `config/flsproject.fnl`.
  - It opens a Fennel buffer, runs `:NfnlCompileAllFiles`, then deletes orphaned generated Lua.
- Safer orphan inspection
  - Run `.agents/skills/neovim-configuration/scripts/recompile-nfnl.py --keep-orphans` to list orphans instead of deleting them.
- Trust requirement
  - `config/.nfnl.fnl` must already have been trusted once in interactive Neovim.
  - The wrapper does not establish trust for you.
- When to recompile
  - After Fennel edits.
  - Definitely after macro changes, renames, deletes, or `config/flsproject.fnl` edits.

## Common maintenance tasks

- Change plugin behavior
  - Start in `config/fnl/plugins/**`.
  - Edit the owning `.fnl` file, then run `.agents/skills/neovim-configuration/scripts/recompile-nfnl.py`.
- Change core options or keymaps
  - Edit `config/fnl/options.fnl` or `config/fnl/keymaps.fnl`.
  - Then run `.agents/skills/neovim-configuration/scripts/recompile-nfnl.py`.
- Change bootstrap or plugin discovery
  - Edit `config/local.lua`.
- Change Nix-managed packages or plugin wiring
  - Edit `default.nix`.
- Change tree-sitter query behavior
  - Edit the relevant `.scm` file directly.
- Rename or delete Fennel files
  - Recompile through `.agents/skills/neovim-configuration/scripts/recompile-nfnl.py`.
  - Use `--keep-orphans` first if you want to inspect before deletion.
  - If this is a plugin file, keep the renamed path within discovery depth `3`.
- Change FLS / project metadata
  - Edit `config/flsproject.fnl`.
  - Then run `.agents/skills/neovim-configuration/scripts/recompile-nfnl.py`.

## Repo quirks

- `config/local.lua` is tracked bootstrap code, not a disposable local override.
- Plugin specs may rely on `_G.plugin_dirs` from `default.nix`.
- Plugin discovery only walks depth `3`; deeper plugin files are ignored.
- `performance.rtp.reset = false` is deliberate.

## Quick checklist

- Before editing
  - Pick the real source file first.
  - If the change is Fennel behavior, stay in `config/fnl/**`, not generated Lua.
  - If macros, renames, or deletes are involved, plan to run the wrapper.
- Before finishing
  - Recompile changed Fennel through `.agents/skills/neovim-configuration/scripts/recompile-nfnl.py`.
  - Keep `.scm` edits separate from nfnl assumptions.
  - Do not claim generated Lua was updated if you did not run the wrapper.

## Common mistakes

- Editing `config/lua/**` or `config/flsproject.lua`
  - Do not do this.
- Treating `config/local.lua` as machine-local
  - It is tracked bootstrap code.
- Adding plugin files deeper than the scan depth
  - Discovery here only walks depth `3`.
- Forgetting to recompile after macro changes, renames, or deletes
  - Those changes affect more than one generated file.
- Looking for an nfnl step after editing `.scm`
  - Query files bypass nfnl.
