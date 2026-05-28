---
name: neovim-configuration
description: Use BEFORE starting work/research on this repo's Neovim config or neovim in general
---

# Neovim Configuration

- **Use this when:** editing
  `modules/aspects/desktop/desktop/apps/editor/neovim/` or researching Neovim
  behavior from installed help
- **Pairing:** for Fennel work, also load `fennel-development`
- **Path base:** paths below are relative to
  `modules/aspects/desktop/desktop/apps/editor/neovim/`

## First rule

- **Never edit generated Lua:** leave `config/lua/**` and
  `config/flsproject.lua` alone; edit Fennel source, then recompile

## Help-first research

- **Prefer help pages:** for Neovim behavior, options, commands, Lua APIs, and
  plugin docs, search installed help before web search
- **Helper CLI:** run
  `uv run skill://neovim-configuration/scripts/nvim-help.py --help` for tag
  lookup, text search, and tag-context dumps
- **Reference:** detailed workflow, raw commands, and pitfalls live in
  `references/help-search.md`
- **Runtime Lua helper:** for repo-configured headless Lua probes, run
  `uv run skill://neovim-configuration/scripts/nvim-lua.py --help` instead of
  hand-writing `nvim --headless --cmd 'set rtp^=...' -u ...`

## Where changes go

- **Plugin behavior:** `config/fnl/**` is the source of truth for Neovim
  behavior
- **Plugin specs:** most plugin specs live in `config/fnl/plugins/**`
- **Core settings:** core options usually live in `config/fnl/options.fnl` and
  `config/fnl/keymaps.fnl`
- **Bootstrap:** `config/local.lua` is a thin runtime shim; edit
  `config/fnl/bootstrap.fnl`, then recompile
- **Plugin discovery:** `config/fnl/lib/plugin-loader.fnl` recursively scans
  `config/fnl/plugins`
  - skips `_`-prefixed files/dirs and `index.fnl`
  - accepts single lazy specs or vectors of lazy specs
  - ignores nil/false/true/empty exports for helper or side-effect modules
- **nfnl trust boundary:** `config/.nfnl.fnl` is a direct-edit project root
  file; trust it once in interactive Neovim before using the wrapper
- **Nix wiring:** `default.nix` controls packages, runtimepath setup, and
  `_G.plugin_dirs`
- **Tree-sitter queries:** `config/queries/**` and `config/after/queries/**`
  are direct-edit `.scm` files
- **Query pipeline:** tree-sitter query files bypass nfnl
- **FLS metadata:** `config/flsproject.fnl` is the source of truth for project
  metadata
- **Further FLS rules:** detailed `flsproject` and fennel-ls rules live in
  `fennel-development`

## Lib helpers and plugin DSL

- **Lib module shape:** under `config/fnl/lib/`, export public API through
  `(local M {})`, `(fn M.name [...])` or `(λ M.name [...])`, and final `M`
- **No large export tables:** avoid returning a big final literal table or
  populating exports with `tset`; attach public names directly to `M`
- **Neovim wrappers:** prefer `lib/nvim` helpers over raw Vim API calls when a
  wrapper exists, e.g. `v/stdpath`, `v/fs-stat`, `v/autocmd`, `v/extend`,
  `v/contains?`, `v/env`, `v/echo`, `v/has?`
- **Plugin specs:** prefer `(p! ...)` and helpers from `lib/plugins`:
  `event`, `ft`, `keys`, `opts`, `deps`, `version`, `cmd`, `lazy`,
  `config`, `builtin`, and `main`
- **Key specs:** inside `(keys ...)`, prefer `lib/keys` helpers through the
  macros: `bind`, `l`, `c`, `a`, `cmd`, `desc`, `m`, `group`; use
  `kgroup!`/`keys!` for direct which-key registration

```fennel
(p! :foo/bar
    (event :VeryLazy)
    (keys
      (bind (l :xx)
            (cmd "SomeCommand")
            (desc "Do thing")
            (m :n :x)))
    (opts {}))
```

## Recompile workflow

- **Preferred wrapper:** from `.agents/skills/neovim-configuration`, run
  `uv run scripts/recompile-nfnl.py`
- **Startup isolation:** the wrapper uses a temporary `XDG_CONFIG_HOME`,
  `-u NONE`, and an explicit nfnl runtimepath so stale generated Lua cannot
  load before recompilation
- **Repo root:** the helper is skill-local and finds the repo root by
  searching upward for `flake.nix`, so caller cwd does not matter
- **Project anchor:** the default anchor is
  `modules/aspects/desktop/desktop/apps/editor/neovim/config/flsproject.fnl`
- **nfnl root:** from that anchor, the helper finds the nearest parent with
  `.nfnl.fnl`
- **Compile action:** it opens a Fennel buffer, calls
  `nfnl.api.compile-all-files`, prints status counts/errors, and exits
  non-zero on compile failures
- **Orphan handling:** after successful compile, it scans or deletes generated
  Lua orphans directly; `--keep-orphans` only lists them
- **When to recompile:** recompile after Fennel edits, especially after macro
  changes, renames, deletes, or `config/flsproject.fnl` edits
- **Bootstrap creation:** `config/local.lua` needs generated
  `config/lua/bootstrap.lua`; compile it before switching the shim on a clean
  tree

## Quick Neovim checks

- **Compile first:** after Fennel edits, run
  `uv run skill://neovim-configuration/scripts/recompile-nfnl.py` from the
  repo
- **Startup smoke:** run `nvim --headless +qa` for a fast config load check
- **Eager smoke:** when lazy/eager loading changes, run
  `NVIM_EAGER_PLUGINS=1 nvim --headless "+lua local s=require('lazy').stats(); if s.loaded ~= s.count then error(('lazy loaded %d/%d plugins'):format(s.loaded, s.count)) end; print(('lazy loaded %d/%d plugins'):format(s.loaded, s.count))" +qa`
- **Lua probe:** run arbitrary Lua against this repo config with
  `uv run skill://neovim-configuration/scripts/nvim-lua.py 'print(vim.inspect(vim.o.cmdheight))'`
  - use `--defer-ms 200` when checking lazy/which-key state scheduled after
    startup

## Common maintenance tasks

- **Change plugin behavior:** edit `config/fnl/plugins/**`, then recompile
  through the wrapper
- **Change core options or keymaps:** edit `config/fnl/options.fnl` or
  `config/fnl/keymaps.fnl`, then recompile
- **Change bootstrap or plugin discovery:** edit `config/fnl/bootstrap.fnl` or
  `config/fnl/lib/plugin-loader.fnl`, then recompile
- **Change Nix-managed packages or plugin wiring:** edit `default.nix`
- **Change tree-sitter query behavior:** edit the relevant `.scm` file
  directly
- **Rename or delete Fennel files:** recompile through the wrapper after the
  change
- **Orphan review:** use `--keep-orphans` first if you want to inspect before
  deletion
- **Change FLS or project metadata:** edit `config/flsproject.fnl`, then
  recompile

## Repo quirks

- **Tracked bootstrap shim:** `config/local.lua` is tracked and should stay a
  small `require("bootstrap")` shim
- **Static plugin dirs:** plugin specs may rely on `_G.plugin_dirs` from
  `default.nix`
- **Why it matters:** that is how this repo threads Nix-provided paths into
  dynamic behavior
- **Plugin helper files:** use `_`-prefixed files/dirs for sibling helpers
  that should not be auto-required
- **Runtimepath reset:** `performance.rtp.reset = false` is deliberate

## Quick checklist

- **Before editing:** pick the real source file first
- **Fennel changes:** if the change is Fennel behavior, stay in
  `config/fnl/**`, not generated Lua
- **Rename-sensitive work:** if macros, renames, or deletes are involved, plan
  to run the wrapper
- **Before finishing:** recompile changed Fennel through the wrapper
- **Query boundary:** keep `.scm` edits separate from nfnl assumptions
- **Claim discipline:** do not claim generated Lua changed if you did not run
  the wrapper

## Common mistakes

- **Generated Lua edits:** do not edit `config/lua/**` or
  `config/flsproject.lua`
- **Local override assumption:** `config/local.lua` is tracked bootstrap code
- **Helper auto-load surprises:** non-underscore `.fnl` files under
  `config/fnl/plugins` are required during discovery
- **Missed recompiles:** macro changes, renames, and deletes affect more than
  one generated file
- **nfnl on queries:** `.scm` query files bypass nfnl
