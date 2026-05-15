-- [nfnl] fnl/bootstrap.fnl
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.loader.enable()
local uv = (vim.uv or vim.loop)
local lazypath = (vim.fn.stdpath("data") .. "/lazy/lazy.nvim")
if not uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({"git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath})
  if (vim.v.shell_error ~= 0) then
    vim.api.nvim_echo({{"Failed to clone lazy.nvim:\n", "ErrorMsg"}, {out, "WarningMsg"}, {"\nPress any key to exit..."}}, true, {})
    vim.fn.getchar()
    os.exit(1)
  else
  end
else
end
vim.opt.rtp:prepend(lazypath)
_G.Config = {}
local function _3_(...)
  return Snacks.debug.inspect(...)
end
_G.dd = _3_
local function _4_()
  return Snacks.debug.backtrace()
end
_G.bt = _4_
if (vim.fn.has("nvim-0.11") == 1) then
  local function _5_(_, ...)
    return dd(...)
  end
  vim._print = _5_
else
  vim.print = dd
end
do
  local plugin_loader = require("lib.plugin-loader")
  local plugins
  local function _7_(...)
    local tmp_9_ = {priority = 1000, lazy = false}
    tmp_9_[1] = "Olical/nfnl"
    return tmp_9_
  end
  plugins = {_7_(...)}
  vim.list_extend(plugins, plugin_loader.load())
  require("lazy").setup(plugins, {ui = {border = "rounded"}, performance = {rtp = {reset = false}}})
end
return require("options")
