-- [nfnl] fnl/plugins/lsp/languages/typescript.fnl
local _local_1_ = require("lib/nvim")
local v_2fautocmd = _local_1_["v/autocmd"]
local js_ts_filetypes = {"javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx"}
local function _2_()
  local function _3_(ev)
    local function _4_()
      local name_1_auto = require("lazy")
      local fun_2_auto = name_1_auto.load
      return fun_2_auto({plugins = {"typescript-tools.nvim"}})
    end
    return vim.api.nvim_buf_call(ev.buf, _4_)
  end
  return v_2fautocmd("FileType", {pattern = js_ts_filetypes, once = true, callback = _3_})
end
return {{"pmizio/typescript-tools.nvim", dependencies = {"nvim-lua/plenary.nvim", "neovim/nvim-lspconfig"}, lazy = true, init = _2_, opts = {}}, {"folke/ts-comments.nvim", opts = {}, event = "VeryLazy"}}
