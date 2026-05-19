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
  _3_.add(_2_.specs(_2_.group("tab", _2_.bind("c", _2_.cmd("tabnew"), _2_.desc("Create")), _2_.bind("l", _2_.cmd("tabnext"), _2_.desc("Next")), _2_.bind("h", _2_.cmd("tabprev"), _2_.desc("Prev")), _2_.bind("d", _2_.cmd("tabclose"), _2_.desc("Close")))))
end
do
  local _4_ = require("lib.keys")
  local _5_ = require("which-key")
  _5_.add(_4_.specs(_4_.group("window", _4_.bind("d", _4_.cmd("quit"), _4_.desc("Quit window")), _4_.bind("D", _4_.cmd("quitall"), _4_.desc("Quit all windows")), _4_.bind("w", _4_.cmd("b#"), _4_.desc("Alternate window buffers")))))
end
do
  local _6_ = require("lib.keys")
  local _7_ = require("which-key")
  _7_.add(_6_.specs(_6_.bind("<leader>|", _6_.cmd("vsplit"), _6_.desc("Split Vertical")), _6_.bind("<leader>-", _6_.cmd("split"), _6_.desc("Split Horizontal"))))
end
do
  local _8_ = require("lib.keys")
  local _9_ = require("which-key")
  _9_.add(_8_.specs(_8_.group("buffer")))
end
do
  local _10_ = require("lib.keys")
  local _11_ = require("which-key")
  _11_.add(_10_.specs(_10_.group("fuzzy")))
end
do
  local _12_ = require("lib.keys")
  local _13_ = require("which-key")
  _13_.add(_12_.specs(_12_.group("git")))
end
do
  local _14_ = require("lib.keys")
  local _15_ = require("which-key")
  local function _16_()
    return vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
  end
  _15_.add(_14_.specs(_14_.group("code", _14_.bind("h", _16_, _14_.desc("Toggle inlay hints")), _14_.bind("r", vim.lsp.buf.rename, _14_.desc("Rename")), _14_.bind("d", vim.diagnostic.open_float, _14_.desc("Diagnostic")))))
end
do
  local _17_ = require("lib.keys")
  local _18_ = require("which-key")
  _18_.add(_17_.specs(_17_.group("diagnostics")))
end
do
  local _19_ = require("lib.keys")
  local _20_ = require("which-key")
  _20_.add(_19_.specs(_19_.group("debug")))
end
do
  local _21_ = require("lib.keys")
  local _22_ = require("which-key")
  _22_.add(_21_.specs(_21_.group("ai")))
end
do
  local _23_ = require("lib.keys")
  local _24_ = require("which-key")
  _24_.add(_23_.specs(_23_.group("repl")))
end
do
  local _25_ = require("lib.keys")
  local _26_ = require("which-key")
  local function _27_()
    local cfg = "~/.config/nvim/.nfnl.fnl"
    v_2f_24(("NfnlCompileAllFiles " .. cfg))
    v_2f_24(("NfnlDeleteOrphans " .. cfg))
    return v_2fn("Done compiled all files and deleted orphans")
  end
  _26_.add(_25_.specs(_25_.group("meta", _25_.bind("n", _27_, _25_.desc("Nfnl Refresh")))))
end
return v_2fmap({"t"}, "<Esc><Esc>", "<C-\\><C-n>", {desc = "Exit terminal mode"})
