# Neovim Help Search

Use installed help before web search for Neovim behavior, options, commands,
Lua APIs, and plugin docs. Local help matches the actual Neovim build and
runtimepath, while web pages may describe a different version or plugin state.

## Helper CLI

Run from anywhere in the repo:

```sh
uv run skill://neovim-configuration/scripts/nvim-help.py --help
```

Default mode uses `nvim --headless -u NONE`, so it searches core Neovim help
without loading this repo's config. Add `--with-config` before the subcommand
when plugin help pages or configured runtimepath docs matter.

### Common commands

```sh
# Find likely help tags, like command-line CTRL-D after :help word
uv run skill://neovim-configuration/scripts/nvim-help.py tags window

# Search help text; phrases can be passed as words
uv run skill://neovim-configuration/scripts/nvim-help.py search vertical split

# Search with a Vim regexp; quote shell-sensitive patterns
uv run skill://neovim-configuration/scripts/nvim-help.py search 'vertical.*split'

# Print context around the exact help tag
uv run skill://neovim-configuration/scripts/nvim-help.py page :vertical

# Print the whole help buffer for a tag or file topic
uv run skill://neovim-configuration/scripts/nvim-help.py page windows --context 0

# Include plugin docs from the configured runtimepath
uv run skill://neovim-configuration/scripts/nvim-help.py --with-config search 'vsplit'
```

## Runtime Lua probes

Use `scripts/nvim-lua.py` when help research needs live config state, plugin
internals, mappings, or scheduled startup state. It loads this repo config
with the same runtimepath/local.lua wrapper used by manual headless probes.

```sh
# Run a small immediate Lua probe
uv run skill://neovim-configuration/scripts/nvim-lua.py 'print(vim.inspect(vim.o.cmdheight))'

# Check state that is scheduled after startup, such as which-key setup
uv run skill://neovim-configuration/scripts/nvim-lua.py --defer-ms 200 'local cfg=require("which-key.config"); print(vim.inspect(cfg.triggers.mappings))'

# Avoid shell-quoting large snippets by using a temporary Lua file
uv run skill://neovim-configuration/scripts/nvim-lua.py --file /tmp/probe.lua
```

The helper auto-quits after the snippet. Pass `--no-auto-quit` only when the
snippet exits Neovim itself.

## Search workflow

1. **Tags first:** run `tags QUERY` when you know a command, option, function,
   or topic prefix
2. **Page next:** run `page TAG` for exact docs around the jumped-to help tag
3. **Text search:** run `search QUERY` when the tag is unknown or wording is
   uncertain
4. **Config docs:** repeat with `--with-config` for plugin-specific behavior
5. **Web last:** use web search only if installed help is absent or unclear;
   verify any answer against local help before acting

## Raw Neovim commands

`:helpgrep` syntax is not slash-delimited. Use the pattern as the command
argument:

```sh
nvim --headless -u NONE +'silent helpgrep vertical split\c' \
  +'lua for _, item in ipairs(vim.fn.getqflist()) do io.write(vim.fn.bufname(item.bufnr) .. ":" .. item.lnum .. ": " .. item.text .. "\n") end' \
  +qa
```

For exact tags, print around the cursor line because `:help {tag}` opens the
file and jumps to the tag, but dumping from line 1 only shows the top of the
help file:

```sh
nvim --headless -u NONE +'help :vertical' \
  +'lua local row=vim.api.nvim_win_get_cursor(0)[1]; local lines=vim.api.nvim_buf_get_lines(0, math.max(0, row-6), row+12, false); io.write(table.concat(lines, "\n") .. "\n")' \
  +qa
```

## Pitfalls

- **No `/pattern/` delimiters:** `:helpgrep /foo/` searches for literal
  slashes; use `:helpgrep foo`. The helper strips one outer slash pair for
  convenience
- **Vim regexps:** `:helpgrep` uses Vim regexp syntax, not PCRE. The helper is
  case-insensitive by default by appending `\c`; pass `--case-sensitive` to
  keep raw helpgrep behavior
- **No command chaining:** `:helpgrep` consumes the rest of the command line
  as the pattern. Use Lua, or the helper, when collecting quickfix results
- **Config isolation:** prefer default `-u NONE` for core docs. Use
  `--with-config` only when plugin docs are needed or runtimepath differences
  matter
- **Plugin docs:** if plugin help is missing, confirm helptags exist for that
  plugin before trusting absence
