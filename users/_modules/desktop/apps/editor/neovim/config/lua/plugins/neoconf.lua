-- [nfnl] fnl/plugins/neoconf.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_21_auto = {}
for __22_auto, attrs_23_auto in ipairs({_1_.event("VeryLazy"), _1_.opts({local_settings = ".neoconf.json", global_settings = "neoconf.json", plugins = {lspconfig = {enabled = false}, jsonls = {enabled = false}, lua_ls = {enabled = false}}, import = {coc = false, nlsp = false, vscode = false}, live_reload = false})}) do
  for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
    spec_21_auto[key_24_auto] = value_25_auto
  end
end
spec_21_auto[1] = "folke/neoconf.nvim"
return spec_21_auto
