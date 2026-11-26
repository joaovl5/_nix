-- [nfnl] fnl/plugins/lsp/languages/pest.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_24_auto = {}
for __25_auto, attrs_26_auto in ipairs({_1_.deps({"nvim-treesitter/nvim-treesitter"}), _1_.opts({})}) do
  for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
    spec_24_auto[key_27_auto] = value_28_auto
  end
end
spec_24_auto[1] = "miguelflor/pest.nvim"
return spec_24_auto
