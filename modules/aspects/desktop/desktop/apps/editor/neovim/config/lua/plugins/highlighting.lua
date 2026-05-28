-- [nfnl] fnl/plugins/highlighting.fnl
local _local_1_ = require("lib/nvim")
local v_2fautocmd = _local_1_["v/autocmd"]
local v_2fextend = _local_1_["v/extend"]
vim.filetype.add({extension = {kbd = "kanata"}})
local languages = {"css", "fennel", "html", "javascript", "jsx", "kanata", "lua", "markdown", "python", "scss", "tsx", "typescript", "vimdoc"}
do
  local ts = require("nvim-treesitter.config")
  ts.setup({auto_install = false})
end
vim.treesitter.language.register("kanata", "kanata")
do
  local filetypes
  do
    local res = {}
    for _, lang in ipairs(languages) do
      res = v_2fextend(res, vim.treesitter.language.get_filetypes(lang))
    end
    filetypes = res
  end
  local function _2_(ev)
    return vim.treesitter.start(ev.buf)
  end
  v_2fautocmd("FileType", {pattern = filetypes, callback = _2_})
end
return {{"m-demare/hlargs.nvim", event = "VeryLazy", opts = {}}}
