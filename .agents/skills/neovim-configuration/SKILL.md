---
name: neovim-configuration
description: Use when editing this repo's Neovim config under users/_modules/desktop/apps/editor/neovim; covers source-vs-generated boundaries, the recompile wrapper, and common maintenance pitfalls
---

# Neovim Configuration

- **Use this when:** editing `users/_modules/desktop/apps/editor/neovim/`
- **Pairing:** for Fennel work, also load `fennel-development`
- **Path base:** paths below are relative to `users/_modules/desktop/apps/editor/neovim/`

## First rule

- **Never edit generated Lua:** leave `config/lua/**` and `config/flsproject.lua` alone; edit Fennel source, then recompile

## Where changes go

- **Plugin behavior:** `config/fnl/**` is the source of truth for Neovim behavior
- **Plugin specs:** most plugin specs live in `config/fnl/plugins/**`
- **Core settings:** core options usually live in `config/fnl/options.fnl` and `config/fnl/keymaps.fnl`
- **Bootstrap:** `config/local.lua` is the real runtime bootstrap for lazy.nvim and nfnl
- **Plugin discovery:** the bootstrap scans `config/fnl/plugins` to depth `3`
- **nfnl trust boundary:** `config/.nfnl.fnl` is a direct-edit project root file; trust it once in interactive Neovim before using the wrapper
- **Nix wiring:** `default.nix` controls packages, runtimepath setup, and `_G.plugin_dirs`
- **Tree-sitter queries:** `config/queries/**` and `config/after/queries/**` are direct-edit `.scm` files
- **Query pipeline:** tree-sitter query files bypass nfnl
- **FLS metadata:** `config/flsproject.fnl` is the source of truth for project metadata
- **Further FLS rules:** detailed `flsproject` and fennel-ls rules live in `fennel-development`

## Recompile workflow

- **Preferred wrapper:** from `.agents/skills/neovim-configuration`, run `uv run scripts/recompile-nfnl.py`
- **Repo root:** the helper is skill-local and finds the repo root by searching upward for `flake.nix`, so caller cwd does not matter
- **Project anchor:** the default anchor is `users/_modules/desktop/apps/editor/neovim/config/flsproject.fnl`
- **nfnl root:** from that anchor, the helper finds the nearest parent with `.nfnl.fnl`
- **Compile action:** it opens a Fennel buffer there and runs `:NfnlCompileAllFiles`
- **Orphan handling:** after compile, it lists or deletes orphaned generated Lua
- **Safer orphan inspection:** run `uv run scripts/recompile-nfnl.py --keep-orphans` to list orphans instead of deleting them
- **When to recompile:** recompile after Fennel edits, especially after macro changes, renames, deletes, or `config/flsproject.fnl` edits

## Common maintenance tasks

- **Change plugin behavior:** edit `config/fnl/plugins/**`, then recompile through the wrapper
- **Change core options or keymaps:** edit `config/fnl/options.fnl` or `config/fnl/keymaps.fnl`, then recompile
- **Change bootstrap or plugin discovery:** edit `config/local.lua`
- **Change Nix-managed packages or plugin wiring:** edit `default.nix`
- **Change tree-sitter query behavior:** edit the relevant `.scm` file directly
- **Rename or delete Fennel files:** recompile through the wrapper after the change
- **Orphan review:** use `--keep-orphans` first if you want to inspect before deletion
- **Discovery limit:** keep plugin files within discovery depth `3`
- **Change FLS or project metadata:** edit `config/flsproject.fnl`, then recompile

## Repo quirks

- **Tracked bootstrap:** `config/local.lua` is tracked bootstrap code, not a disposable local override
- **Static plugin dirs:** plugin specs may rely on `_G.plugin_dirs` from `default.nix`
- **Why it matters:** that is how this repo threads Nix-provided paths into dynamic behavior
- **Discovery depth:** plugin discovery only walks depth `3`; deeper plugin files are ignored
- **Runtimepath reset:** `performance.rtp.reset = false` is deliberate

## Quick checklist

- **Before editing:** pick the real source file first
- **Fennel changes:** if the change is Fennel behavior, stay in `config/fnl/**`, not generated Lua
- **Rename-sensitive work:** if macros, renames, or deletes are involved, plan to run the wrapper
- **Before finishing:** recompile changed Fennel through the wrapper
- **Query boundary:** keep `.scm` edits separate from nfnl assumptions
- **Claim discipline:** do not claim generated Lua changed if you did not run the wrapper

## Common mistakes

- **Generated Lua edits:** do not edit `config/lua/**` or `config/flsproject.lua`
- **Local override assumption:** `config/local.lua` is tracked bootstrap code
- **Deep plugin files:** discovery only walks depth `3`
- **Missed recompiles:** macro changes, renames, and deletes affect more than one generated file
- **nfnl on queries:** `.scm` query files bypass nfnl
