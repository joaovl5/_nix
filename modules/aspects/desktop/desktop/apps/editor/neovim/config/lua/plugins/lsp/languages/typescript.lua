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
local function _5_()
  local function _6_(ev)
    local function _7_()
      local name_1_auto = require("lazy")
      local fun_2_auto = name_1_auto.load
      return fun_2_auto({plugins = {"typescript-tools.nvim"}})
    end
    return vim.api.nvim_buf_call(ev.buf, _7_)
  end
  return v_2fautocmd("FileType", {pattern = js_ts_filetypes, once = true, callback = _6_})
end
return {_4_, {"pmizio/typescript-tools.nvim", dependencies = {"nvim-lua/plenary.nvim", "neovim/nvim-lspconfig"}, lazy = true, init = _5_, opts = {}}, {"folke/ts-comments.nvim", opts = {}, event = "VeryLazy"}}
