-- define leader key first to avoid conflicts
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- setup mini-deps and hotpot
local path_package = vim.fn.stdpath 'data' .. '/site/'

local function ensure_installed(plugin, branch)
  local user, repo = string.match(plugin, '(.+)/(.+)')
  local repo_path = path_package .. 'pack/deps/start/' .. repo
  if not (vim.uv or vim.loop).fs_stat(repo_path) then
    vim.notify('Installing ' .. plugin .. ' ' .. branch)
    local repo_url = 'https://github.com/' .. plugin
    local out = vim.fn.system {
      'git',
      'clone',
      '--filter=blob:none',
      '--branch=' .. branch,
      repo_url,
      repo_path,
    }
    if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo({
        { 'Failed to clone ' .. plugin .. ':\n', 'ErrorMsg' },
        { out, 'WarningMsg' },
        { '\nPress any key to exit...' },
      }, true, {})
      vim.fn.getchar()
      os.exit(1)
    end
    vim.cmd('packadd ' .. repo .. ' | helptags ALL')
    vim.cmd('echo "Installed `' .. repo .. '`" | redraw')
  end
end

ensure_installed('echasnovski/mini.nvim', 'stable')

-- ensure_installed('rktjmp/hotpot.nvim', 'v0.14.8')
ensure_installed('aileot/nvim-thyme', 'main')
-- Wrapping the `require` in `function-end` is important for lazy-load.
table.insert(package.loaders, function(...)
  return require('thyme').loader(...) -- Make sure to `return` the result!
end)

-- Note: Add a cache path to &rtp. The path MUST include the literal substring "/thyme/compile".
local thyme_cache_prefix = vim.fn.stdpath 'cache' .. '/thyme/compiled'
vim.opt.rtp:prepend(thyme_cache_prefix)
-- Note: `vim.loader` internally cache &rtp, and recache it if modified.
-- Please test the best place to `vim.loader.enable()` by yourself.
vim.loader.enable() -- (optional) before the `bootstrap`s above, it could increase startuptime.

require('mini.deps').setup {
  path = {
    package = path_package,
  },
}

-- define global cfg
_G.Config = {}

-- autocommand group helper
local gr = vim.api.nvim_create_augroup('lav-config', {})
_G.Config.new_autocmd = function(event, pattern, callback, desc)
  local opts = { group = gr, pattern = pattern, callback = callback, desc = desc }
  vim.api.nvim_create_autocmd(event, opts)
end

-- some plugins and 'mini.nvim' modules only need setup during startup if neovim
-- is started like `nvim -- path/to/file`, otherwise delaying setup is fine
_G.Config.now_or_later = vim.fn.argc(-1) > 0 and MiniDeps.now or MiniDeps.later

require 'options'
require 'keymaps'
require 'plugins._index'
