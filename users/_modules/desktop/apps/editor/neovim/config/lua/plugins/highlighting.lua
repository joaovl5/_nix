-- [nfnl] fnl/plugins/highlighting.fnl
local n = require("lib/nvim")
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
      res = vim.list_extend(res, vim.treesitter.language.get_filetypes(lang))
    end
    filetypes = res
  end
  local function _1_(ev)
    return vim.treesitter.start(ev.buf)
  end
  n.autocmd("FileType", {pattern = filetypes, callback = _1_})
end
return {{"m-demare/hlargs.nvim", event = "VeryLazy", opts = {}}}
