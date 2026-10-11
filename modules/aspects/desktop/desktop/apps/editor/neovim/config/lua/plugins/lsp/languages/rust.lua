-- [nfnl] fnl/plugins/lsp/languages/rust.fnl
vim.g.rustaceanvim = {tools = {enable_clippy = true}, server = {lspmux = {enable = true}, default_settings = {["rust-analyzer"] = {checkOnSave = true, imports = {prefix = "self", granularity = {group = "module"}}, cargo = {targetDir = true, buildScripts = {enable = true}}, procMacro = {enable = true}, diagnostics = {experimental = {enable = true}}}}}}
local _3_
do
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_1_.lazy(false), _1_.version("^9")}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "mrcjkb/rustaceanvim"
  _3_ = spec_24_auto
end
local function _6_(...)
  local _4_ = require("lib.plugins")
  local _5_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_4_.opts({quickfix = {enabled = true, event_trigger = true}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "Canop/nvim-bacon"
  return spec_24_auto
end
return {_3_, _6_(...)}
