-- [nfnl] fnl/plugins/treesitter.fnl
local n = require("lib/nvim")
local languages = {"lua", "vimdoc", "markdown", "python", "javascript", "jsx", "typescript", "tsx", "html", "css", "scss"}
local function _1_()
  do
    local ts = require("nvim-treesitter")
    ts.setup({})
    ts.install(languages)
  end
  local filetypes
  do
    local res = {}
    for _, lang in ipairs(languages) do
      res = vim.list_extend(res, vim.treesitter.language.get_filetypes(lang))
    end
    filetypes = res
  end
  local function _2_(ev)
    return vim.treesitter.start(ev.buf)
  end
  return n.autocmd("FileType", {pattern = filetypes, callback = _2_})
end
return {{"nvim-treesitter/nvim-treesitter", branch = "main", build = ":TSUpdate", config = _1_, lazy = false}}
