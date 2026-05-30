-- [nfnl] fnl/plugins/lsp/languages/json.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_24_auto = {}
for __25_auto, attrs_26_auto in ipairs({_1_.cmd("Videre"), _1_.deps({"Owen-Dechow/graph_view_yaml_parser", "Owen-Dechow/graph_view_toml_parser", "a-usr/xml2lua.nvim"}), _1_.opts({editor_type = "split", simple_statusline = false})}) do
  for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
    spec_24_auto[key_27_auto] = value_28_auto
  end
end
spec_24_auto[1] = "Owen-Dechow/videre.nvim"
return spec_24_auto
