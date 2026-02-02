-- [nfnl] fnl/plugins/treesitter.fnl
local n = require("lib/nvim")
local languages = {"lua", "vimdoc", "markdown", "javascript", "jsx", "typescript", "tsx", "html", "css", "scss"}
local function isnt_lang_installed(lang)
  return (#vim.api.nvim_get_runtime_file(("parser/" .. lang .. ".*"), false) == 0)
end
local function _1_()
  do
    local ts = require("nvim-treesitter")
    local should_install = false
    local to_install = vim.tbl_filter(isnt_lang_installed, languages)
    if ((#to_install > 0) and false) then
      ts.install(to_install)
    else
    end
  end
  local filetypes
  do
    local res = {}
    for _, lang in ipairs(languages) do
      res = vim.list_extend(res, vim.treesitter.language.get_filetypes(lang))
    end
    filetypes = res
  end
  local function _3_(ev)
    return vim.treesitter.start(ev.buf)
  end
  return n.autocmd("FileType", {pattern = filetypes, callback = _3_})
end
return {{"nvim-treesitter/nvim-treesitter", branch = "main", build = ":TSUpdate", config = _1_, lazy = false}}
