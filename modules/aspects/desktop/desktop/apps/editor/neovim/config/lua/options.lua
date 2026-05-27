-- [nfnl] fnl/options.fnl
local _local_1_ = require("lib/nvim")
local v_2f_24 = _local_1_["v/$"]
local v_2fautocmd = _local_1_["v/autocmd"]
local v_2flater = _local_1_["v/later"]
local opts = {mouse = "a", mousescroll = "ver:15,hor:6", switchbuf = "usetab", undolevels = 10000, undofile = true, shada = "'100,<50,s10,:1000,/100,@100,h", termguicolors = true, redrawtime = 10000, maxmempattern = 20000, smoothscroll = true, confirm = true, hidden = true, backspace = "indent,eol,start", sessionoptions = "curdir,folds,globals,help,tabpages,terminal,winsize", updatetime = 500, timeoutlen = 250, background = "dark", colorcolumn = "+1", number = true, relativenumber = true, list = true, listchars = "tab:\194\187 ,trail:\194\183,nbsp:\226\144\163", fillchars = "eob: ,fold:\226\149\140", linebreak = true, breakindent = true, breakindentopt = "list:-1", cursorline = true, cursorcolumn = true, cursorlineopt = "screenline,number", signcolumn = "yes", splitbelow = true, splitright = true, splitkeep = "screen", winborder = "solid", winblend = 0, pumheight = 10, pummaxwidth = 60, pumblend = 10, cmdheight = 0, foldlevel = 99, foldmethod = "indent", foldnestmax = 10, foldtext = "", spelloptions = "camel", virtualedit = "block", iskeyword = "@,48-57,_,192-255,-", scrolloff = 10, complete = ".,w,b,kspell", completeopt = "menuone,noselect,fuzzy,nosort", autoindent = true, smartindent = true, expandtab = true, shiftwidth = 2, tabstop = 2, formatlistpat = "^\\s*[0-9\\-\\+\\*]\\+[\\.\\)]*\\s\\+", formatoptions = "rqnl1", ignorecase = true, incsearch = true, smartcase = true, errorbells = false, ruler = false, showmode = false, swapfile = false, wrap = false}
local neovide_opts = {neovide_refresh_rate = 240, neovide_cursor_animation_length = 0.04, neovide_cursor_trail_size = 0.4, neovide_scroll_animation_length = 0.15, neovide_position_animation_length = 0.04, neovide_light_radius = 2, neovide_cursor_animate_in_insert_mode = false}
for opt, val in pairs(opts) do
  vim.opt[opt] = val
end
for opt, val in pairs(neovide_opts) do
  vim.g[opt] = val
end
local function _2_()
  vim.o.clipboard = "unnamedplus"
  return nil
end
v_2flater(_2_)
v_2f_24("filetype plugin indent on")
if (1 ~= vim.fn.exists("syntax_on")) then
  v_2f_24("syntax enable")
else
end
local diagnostic_opts
local _4_
do
  local tmp_9_ = {}
  tmp_9_[vim.diagnostic.severity.ERROR] = "\243\176\133\154 "
  tmp_9_[vim.diagnostic.severity.WARN] = "\243\176\128\170 "
  tmp_9_[vim.diagnostic.severity.INFO] = "\243\176\139\189 "
  tmp_9_[vim.diagnostic.severity.HINT] = "\243\176\140\182 "
  _4_ = tmp_9_
end
diagnostic_opts = {severity_sort = true, float = {border = "rounded", source = "if_many"}, signs = {priority = 9999, severity = {min = "WARN", max = "ERROR"}, text = _4_}, underline = {severity = {"ERROR"}}, virtual_text = {source = "if_many", spacing = 2, current_line = true, severity = {"ERROR"}}, update_in_insert = false, virtual_lines = false}
local function _5_()
  return vim.diagnostic.config(diagnostic_opts)
end
v_2flater(_5_)
local function _6_()
  return v_2f_24("setlocal formatoptions-=c formatoptions-=o")
end
return v_2fautocmd("FileType", {desc = "Proper 'formatoptions'", callback = _6_})
