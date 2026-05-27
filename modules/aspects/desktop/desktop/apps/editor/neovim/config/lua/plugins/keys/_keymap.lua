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
  _3_.add(_2_.specs(_2_.bind("<C-h>", _2_.cmd("wincmd h"), _2_.desc("Focus left"), _2_.m("n", "t")), _2_.bind("<C-j>", _2_.cmd("wincmd j"), _2_.desc("Focus down"), _2_.m("n", "t")), _2_.bind("<C-k>", _2_.cmd("wincmd k"), _2_.desc("Focus up"), _2_.m("n", "t")), _2_.bind("<C-l>", _2_.cmd("wincmd l"), _2_.desc("Focus right"), _2_.m("n", "t"))))
end
do
  local _4_ = require("lib.keys")
  local _5_ = require("which-key")
  _5_.add(_4_.specs(_4_.group("action_1", _4_.bind("h", _4_.cmd("wincmd H"), _4_.desc("Move left")), _4_.bind("j", _4_.cmd("wincmd J"), _4_.desc("Move down")), _4_.bind("k", _4_.cmd("wincmd K"), _4_.desc("Move up")), _4_.bind("l", _4_.cmd("wincmd L"), _4_.desc("Move right")), _4_.bind("x", _4_.cmd("wincmd x"), _4_.desc("Swap current/next")), _4_.bind("t", _4_.cmd("wincmd t"), _4_.desc("Break to tab")))))
end
do
  local _6_ = require("lib.keys")
  local _7_ = require("which-key")
  _7_.add(_6_.specs(_6_.group("action_2", _6_.bind("c", _6_.cmd("tabnew"), _6_.desc("Create")), _6_.bind("l", _6_.cmd("tabnext"), _6_.desc("Next")), _6_.bind("h", _6_.cmd("tabprev"), _6_.desc("Prev")), _6_.bind("d", _6_.cmd("tabclose"), _6_.desc("Close")))))
end
do
  local _8_ = require("lib.keys")
  local _9_ = require("which-key")
  _9_.add(_8_.specs(_8_.group("marks")))
end
do
  local _10_ = require("lib.keys")
  local _11_ = require("which-key")
  _11_.add(_10_.specs(_10_.group("tab")))
end
do
  local _12_ = require("lib.keys")
  local _13_ = require("which-key")
  _13_.add(_12_.specs(_12_.group("window", _12_.bind("d", _12_.cmd("quit"), _12_.desc("Quit window")), _12_.bind("D", _12_.cmd("quitall"), _12_.desc("Quit all windows")), _12_.bind("w", _12_.cmd("b#"), _12_.desc("Alternate window buffers")))))
end
do
  local _14_ = require("lib.keys")
  local _15_ = require("which-key")
  _15_.add(_14_.specs(_14_.bind("<leader>|", _14_.cmd("vsplit"), _14_.desc("Split Vertical")), _14_.bind("<leader>-", _14_.cmd("split"), _14_.desc("Split Horizontal"))))
end
do
  local _16_ = require("lib.keys")
  local _17_ = require("which-key")
  _17_.add(_16_.specs(_16_.group("buffer")))
end
do
  local _18_ = require("lib.keys")
  local _19_ = require("which-key")
  _19_.add(_18_.specs(_18_.group("fuzzy")))
end
do
  local _20_ = require("lib.keys")
  local _21_ = require("which-key")
  _21_.add(_20_.specs(_20_.group("git")))
end
do
  local _22_ = require("lib.keys")
  local _23_ = require("which-key")
  local function _24_()
    return vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
  end
  _23_.add(_22_.specs(_22_.group("code", _22_.bind("h", _24_, _22_.desc("Toggle inlay hints")), _22_.bind("r", vim.lsp.buf.rename, _22_.desc("Rename")), _22_.bind("d", vim.diagnostic.open_float, _22_.desc("Diagnostic")))))
end
do
  local _25_ = require("lib.keys")
  local _26_ = require("which-key")
  _26_.add(_25_.specs(_25_.group("diagnostics")))
end
do
  local _27_ = require("lib.keys")
  local _28_ = require("which-key")
  _28_.add(_27_.specs(_27_.group("debug")))
end
do
  local _29_ = require("lib.keys")
  local _30_ = require("which-key")
  _30_.add(_29_.specs(_29_.group("ai")))
end
do
  local _31_ = require("lib.keys")
  local _32_ = require("which-key")
  _32_.add(_31_.specs(_31_.group("repl")))
end
do
  local _33_ = require("lib.keys")
  local _34_ = require("which-key")
  _34_.add(_33_.specs(_33_.group("merge")))
end
do
  local _35_ = require("lib.keys")
  local _36_ = require("which-key")
  local function _37_()
    local cfg = "~/.config/nvim/.nfnl.fnl"
    v_2f_24(("NfnlCompileAllFiles " .. cfg))
    v_2f_24(("NfnlDeleteOrphans " .. cfg))
    return v_2fn("Done compiled all files and deleted orphans")
  end
  _36_.add(_35_.specs(_35_.group("meta", _35_.bind("n", _37_, _35_.desc("Nfnl Refresh")))))
end
return v_2fmap({"t"}, "<Esc><Esc>", "<C-\\><C-n>", {desc = "Exit terminal mode"})
