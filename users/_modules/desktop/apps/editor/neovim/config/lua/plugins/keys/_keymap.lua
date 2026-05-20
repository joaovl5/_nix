-- [nfnl] fnl/plugins/keys/_keymap.fnl
local _local_1_ = require("lib/nvim")
local v_2fmap = _local_1_["v/map"]
local v_2f_24 = _local_1_["v/$"]
local v_2fn = _local_1_["v/n"]
v_2fmap({"n"}, "<Esc>", "<cmd>nohlsearch<CR>", {desc = "Clear Search Highlights"})
v_2fmap({"n"}, "<Esc>", "<cmd>nohlsearch<CR>", {desc = "Clear Search Highlights"})
v_2fmap({"x"}, "p", "\"_dP")
v_2fmap({"n"}, "<C-d>", "<C-d>zz")
v_2fmap({"n"}, "<C-u>", "<C-u>zz")
v_2fmap({"n"}, "n", "nzzzv")
v_2fmap({"n"}, "N", "Nzzzv")
v_2fmap({"x"}, ">", ">gv", {noremap = true})
v_2fmap({"x"}, "<", "<gv", {noremap = true})
do
  local _2_ = require("lib.keys")
  local _3_ = require("which-key")
  _3_.add(_2_.specs(_2_.group("action_1", _2_.bind("h", _2_.cmd("wincmd H"), _2_.desc("Move left")), _2_.bind("j", _2_.cmd("wincmd J"), _2_.desc("Move down")), _2_.bind("k", _2_.cmd("wincmd K"), _2_.desc("Move up")), _2_.bind("l", _2_.cmd("wincmd L"), _2_.desc("Move right")), _2_.bind("x", _2_.cmd("wincmd x"), _2_.desc("Swap current/next")), _2_.bind("t", _2_.cmd("wincmd t"), _2_.desc("Break to tab")))))
end
do
  local _4_ = require("lib.keys")
  local _5_ = require("which-key")
  _5_.add(_4_.specs(_4_.group("action_2", _4_.bind("c", _4_.cmd("tabnew"), _4_.desc("Create")), _4_.bind("l", _4_.cmd("tabnext"), _4_.desc("Next")), _4_.bind("h", _4_.cmd("tabprev"), _4_.desc("Prev")), _4_.bind("d", _4_.cmd("tabclose"), _4_.desc("Close")))))
end
do
  local _6_ = require("lib.keys")
  local _7_ = require("which-key")
  _7_.add(_6_.specs(_6_.group("tab")))
end
do
  local _8_ = require("lib.keys")
  local _9_ = require("which-key")
  _9_.add(_8_.specs(_8_.group("window", _8_.bind("d", _8_.cmd("quit"), _8_.desc("Quit window")), _8_.bind("D", _8_.cmd("quitall"), _8_.desc("Quit all windows")), _8_.bind("w", _8_.cmd("b#"), _8_.desc("Alternate window buffers")))))
end
do
  local _10_ = require("lib.keys")
  local _11_ = require("which-key")
  _11_.add(_10_.specs(_10_.bind("<leader>|", _10_.cmd("vsplit"), _10_.desc("Split Vertical")), _10_.bind("<leader>-", _10_.cmd("split"), _10_.desc("Split Horizontal"))))
end
do
  local _12_ = require("lib.keys")
  local _13_ = require("which-key")
  _13_.add(_12_.specs(_12_.group("buffer")))
end
do
  local _14_ = require("lib.keys")
  local _15_ = require("which-key")
  _15_.add(_14_.specs(_14_.group("fuzzy")))
end
do
  local _16_ = require("lib.keys")
  local _17_ = require("which-key")
  _17_.add(_16_.specs(_16_.group("git")))
end
do
  local _18_ = require("lib.keys")
  local _19_ = require("which-key")
  local function _20_()
    return vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
  end
  _19_.add(_18_.specs(_18_.group("code", _18_.bind("h", _20_, _18_.desc("Toggle inlay hints")), _18_.bind("r", vim.lsp.buf.rename, _18_.desc("Rename")), _18_.bind("d", vim.diagnostic.open_float, _18_.desc("Diagnostic")))))
end
do
  local _21_ = require("lib.keys")
  local _22_ = require("which-key")
  _22_.add(_21_.specs(_21_.group("diagnostics")))
end
do
  local _23_ = require("lib.keys")
  local _24_ = require("which-key")
  _24_.add(_23_.specs(_23_.group("debug")))
end
do
  local _25_ = require("lib.keys")
  local _26_ = require("which-key")
  _26_.add(_25_.specs(_25_.group("ai")))
end
do
  local _27_ = require("lib.keys")
  local _28_ = require("which-key")
  _28_.add(_27_.specs(_27_.group("repl")))
end
do
  local _29_ = require("lib.keys")
  local _30_ = require("which-key")
  _30_.add(_29_.specs(_29_.group("merge")))
end
do
  local _31_ = require("lib.keys")
  local _32_ = require("which-key")
  local function _33_()
    local cfg = "~/.config/nvim/.nfnl.fnl"
    v_2f_24(("NfnlCompileAllFiles " .. cfg))
    v_2f_24(("NfnlDeleteOrphans " .. cfg))
    return v_2fn("Done compiled all files and deleted orphans")
  end
  _32_.add(_31_.specs(_31_.group("meta", _31_.bind("n", _33_, _31_.desc("Nfnl Refresh")))))
end
return v_2fmap({"t"}, "<Esc><Esc>", "<C-\\><C-n>", {desc = "Exit terminal mode"})
