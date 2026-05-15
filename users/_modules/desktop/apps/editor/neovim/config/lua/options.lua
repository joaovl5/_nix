-- [nfnl] fnl/options.fnl
local nvim = require("lib/nvim")
local opts = {{"mouse", "a"}, {"mousescroll", "ver:15,hor:6"}, {"switchbuf", "usetab"}, {"swapfile", false}, {"undofile", true}, {"shada", "'100,<50,s10,:1000,/100,@100,h"}, {"termguicolors", true}, {"sessionoptions", "curdir,folds,globals,help,tabpages,terminal,winsize"}, {"updatetime", 1000}, {"timeoutlen", 300}, {"background", "dark"}, {"colorcolumn", "+1"}, {"number", true}, {"relativenumber", true}, {"list", true}, {"listchars", "tab:\194\187 ,trail:\194\183,nbsp:\226\144\163"}, {"fillchars", "eob: ,fold:\226\149\140"}, {"wrap", false}, {"linebreak", true}, {"breakindent", true}, {"breakindentopt", "list:-1"}, {"cursorline", true}, {"cursorcolumn", true}, {"cursorlineopt", "screenline,number"}, {"ruler", false}, {"showmode", false}, {"signcolumn", "yes"}, {"splitbelow", true}, {"splitright", true}, {"splitkeep", "screen"}, {"winborder", "rounded"}, {"foldlevel", 10}, {"foldmethod", "indent"}, {"foldnestmax", 10}, {"foldtext", ""}, {"spelloptions", "camel"}, {"virtualedit", "block"}, {"iskeyword", "@,48-57,_,192-255,-"}, {"scrolloff", 10}, {"complete", ".,w,b,kspell"}, {"completeopt", "menuone,noselect,fuzzy,nosort"}, {"autoindent", true}, {"smartindent", true}, {"expandtab", true}, {"shiftwidth", 2}, {"tabstop", 2}, {"formatlistpat", "^\\s*[0-9\\-\\+\\*]\\+[\\.\\)]*\\s\\+"}, {"formatoptions", "rqnl1"}, {"ignorecase", true}, {"incsearch", true}, {"smartcase", true}}
do
  local set_opt
  local function _1_(_241, _242)
    vim.opt[_241] = _242
    return nil
  end
  set_opt = _1_
  for _, _2_ in ipairs(opts) do
    local opt = _2_[1]
    local val = _2_[2]
    set_opt(opt, val)
  end
end
local function _3_()
  vim.o.clipboard = "unnamedplus"
  return nil
end
vim.schedule(_3_)
vim.cmd("filetype plugin indent on")
if (1 ~= vim.fn.exists("syntax_on")) then
  vim.cmd("syntax enable")
else
end
local diagnostic_opts
local _5_
do
  local tmp_9_ = {}
  tmp_9_[vim.diagnostic.severity.ERROR] = "\243\176\133\154 "
  tmp_9_[vim.diagnostic.severity.WARN] = "\243\176\128\170 "
  tmp_9_[vim.diagnostic.severity.INFO] = "\243\176\139\189 "
  tmp_9_[vim.diagnostic.severity.HINT] = "\243\176\140\182 "
  _5_ = tmp_9_
end
diagnostic_opts = {severity_sort = true, float = {border = "rounded", source = "if_many"}, signs = {priority = 9999, severity = {min = "WARN", max = "ERROR"}, text = _5_}, underline = {severity = {"ERROR"}}, virtual_text = {source = "if_many", spacing = 2, current_line = true, severity = {"ERROR"}}, update_in_insert = false, virtual_lines = false}
local function _6_()
  return vim.diagnostic.config(diagnostic_opts)
end
vim.schedule(_6_)
local function _7_()
  return vim.cmd("setlocal formatoptions-=c formatoptions-=o")
end
return nvim.autocmd("FileType", {desc = "Proper 'formatoptions'", callback = _7_})
