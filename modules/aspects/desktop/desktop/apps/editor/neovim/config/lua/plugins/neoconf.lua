-- [nfnl] fnl/plugins/neoconf.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_24_auto = {}
for __25_auto, attrs_26_auto in ipairs({_1_.event("VeryLazy"), _1_.opts({local_settings = ".neoconf.json", global_settings = "neoconf.json", plugins = {lspconfig = {enabled = false}, jsonls = {enabled = false}, lua_ls = {enabled = false}}, import = {coc = false, nlsp = false, vscode = false}, live_reload = false})}) do
  for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
    spec_24_auto[key_27_auto] = value_28_auto
  end
end
spec_24_auto[1] = "folke/neoconf.nvim"
return spec_24_auto
