-- [nfnl] fnl/plugins/lsp/languages/rust.fnl
vim.g.rustaceanvim = {tools = {enable_clippy = false}, server = {lspmux = {enable = true}, default_settings = {["rust-analyzer"] = {cargo = {targetDir = true, buildScripts = {enable = true}}, procMacro = {enable = true}, checkOnSave = false}}}}
local function _3_(...)
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_1_.lazy(false), _1_.version("^9")}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "mrcjkb/rustaceanvim"
  return spec_24_auto
end
return {_3_(...)}
