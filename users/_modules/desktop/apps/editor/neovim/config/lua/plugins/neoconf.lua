-- [nfnl] fnl/plugins/neoconf.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_23_auto = {}
for __24_auto, attrs_25_auto in ipairs({_1_.event("VeryLazy"), _1_.opts({local_settings = ".neoconf.json", global_settings = "neoconf.json", plugins = {lspconfig = {enabled = false}, jsonls = {enabled = false}, lua_ls = {enabled = false}}, import = {coc = false, nlsp = false, vscode = false}, live_reload = false})}) do
  for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
    spec_23_auto[key_26_auto] = value_27_auto
  end
end
spec_23_auto[1] = "folke/neoconf.nvim"
return spec_23_auto
