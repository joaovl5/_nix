-- [nfnl] fnl/bootstrap.fnl
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.loader.enable()
local _local_1_ = require("lib/nvim")
local v_2fcontains_3f = _local_1_["v/contains?"]
local v_2fecho = _local_1_["v/echo"]
local v_2fenv = _local_1_["v/env"]
local v_2fextend = _local_1_["v/extend"]
local v_2ffs_stat = _local_1_["v/fs-stat"]
local v_2fgetchar = _local_1_["v/getchar"]
local v_2fhas_3f = _local_1_["v/has?"]
local v_2frtp_prepend = _local_1_["v/rtp-prepend"]
local v_2fstdpath = _local_1_["v/stdpath"]
local v_2fsys = _local_1_["v/sys"]
local _local_2_ = require("lib.utils")
local str_3f = _local_2_["str?"]
local tbl_3f = _local_2_["tbl?"]
local __3elower = _local_2_["->lower"]
local lazypath = (v_2fstdpath("data") .. "/lazy/lazy.nvim")
if not v_2ffs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = v_2fsys({"git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath})
  if (vim.v.shell_error ~= 0) then
    v_2fecho({{"Failed to clone lazy.nvim:\n", "ErrorMsg", {out, "WarningMsg"}, {"\nPress any key to exit..."}}, true, {}})
    v_2fgetchar()
    os.exit(1)
  else
  end
else
end
v_2frtp_prepend(lazypath)
_G.Config = {}
local function _5_(...)
  return Snacks.debug.inspect(...)
end
_G.dd = _5_
local function _6_()
  return Snacks.debug.backtrace()
end
_G.bt = _6_
if v_2fhas_3f("nvim-0.11") then
  local function _7_(_, ...)
    return _G.dd(...)
  end
  vim._print = _7_
else
  vim.print = _G.dd
end
local function single_spec_3f(value)
  return (tbl_3f(value) and (str_3f(value[1]) or str_3f(value.dir) or str_3f(value.import) or str_3f(value.url)) and (value[2] == nil))
end
local function child_specs(value)
  if not tbl_3f(value) then
    return {}
  elseif single_spec_3f(value) then
    return {value}
  else
    return value
  end
end
local function make_eager_spec(spec)
  if tbl_3f(spec) then
    spec.lazy = false
    for _, child in ipairs(child_specs(spec.dependencies)) do
      make_eager_spec(child)
    end
    for _, child in ipairs(child_specs(spec.specs)) do
      make_eager_spec(child)
    end
  else
  end
  return spec
end
local function make_eager_plugins(plugins)
  for _, spec in ipairs(plugins) do
    make_eager_spec(spec)
  end
  return plugins
end
local function truthy_env_3f(value)
  return v_2fcontains_3f({"1", "true", "yes"}, __3elower((value or "")))
end
local function eager_plugins_3f()
  return truthy_env_3f(v_2fenv("NVIM_EAGER_PLUGINS"))
end
require("plugins.keys._groups")
do
  local plugin_loader = require("lib.plugin-loader")
  local plugins
  local function _13_(...)
    local _11_ = require("lib.plugins")
    local _12_ = require("lib.keys")
    local spec_21_auto = {}
    for __22_auto, attrs_23_auto in ipairs({_11_.lazy(false), {priority = 1000}}) do
      for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
        spec_21_auto[key_24_auto] = value_25_auto
      end
    end
    spec_21_auto[1] = "Olical/nfnl"
    return spec_21_auto
  end
  plugins = {_13_(...)}
  v_2fextend(plugins, plugin_loader.load())
  if eager_plugins_3f() then
    make_eager_plugins(plugins)
  else
  end
  require("lazy").setup(plugins, {ui = {border = "rounded"}, performance = {rtp = {reset = false}}})
end
return require("options")
