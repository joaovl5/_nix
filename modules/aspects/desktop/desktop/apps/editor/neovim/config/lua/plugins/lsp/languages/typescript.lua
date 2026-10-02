-- [nfnl] fnl/plugins/lsp/languages/typescript.fnl
local _local_1_ = require("lib/nvim")
local v_2fautocmd = _local_1_["v/autocmd"]
local js_ts_filetypes = {"javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx"}
local _4_
do
  local _2_ = require("lib.plugins")
  local _3_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "HerringtonDarkholme/yats.vim"
  _4_ = spec_24_auto
end
return {_4_, {"folke/ts-comments.nvim", opts = {}, event = "VeryLazy"}}
