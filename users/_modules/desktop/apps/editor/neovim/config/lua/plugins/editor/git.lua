-- [nfnl] fnl/plugins/editor/git.fnl
local _local_1_ = require("lib/nvim")
local v_2fn = _local_1_["v/n"]
local v_2flater = _local_1_["v/later"]
local function handle_conf(x)
  local _2_ = require("lib/nvim")
  return _2_["v/n"](tostring("Found conflicts!"))
end
local _5_
do
  local _3_ = require("lib.plugins")
  local _4_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_3_.event({"BufReadPre", "BufNewFile"}), _3_.keys(_4_.group("merge", _4_.bind("j", _4_.cmd("ResolveNext"), _4_.desc("Next Conflict")), _4_.bind("k", _4_.cmd("ResolvePrev"), _4_.desc("Prev Conflict")), _4_.bind("o", _4_.cmd("ResolveOurs"), _4_.desc("Use Ours")), _4_.bind("t", _4_.cmd("ResolveTheirs"), _4_.desc("Use Theirs")), _4_.bind("O", _4_.cmd("ResolveBoth"), _4_.desc("Use Both (ours first)")), _4_.bind("T", _4_.cmd("ResolveBothReverse"), _4_.desc("Use Both (theirs first)")), _4_.bind("b", _4_.cmd("ResolveBase"), _4_.desc("Use base")), _4_.bind("n", _4_.cmd("ResolveNone"), _4_.desc("Use none")), _4_.bind("l", _4_.cmd("ResolveList"), _4_.desc("List conflicts")), _4_.bind("pt", _4_.cmd("ResolveDiffOursTheirs"), _4_.desc("Preview theirs")), _4_.bind("po", _4_.cmd("ResolveDiffTheirsOurs"), _4_.desc("Preview ours")))), _3_.opts({on_conflict_detected = handle_conf, default_keymaps = false})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "spacedentist/resolve.nvim"
  _5_ = spec_24_auto
end
local _8_
do
  local _6_ = require("lib.plugins")
  local _7_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_6_.cmd("Neogit"), _6_.deps({"esmuellert/codediff.nvim", "m00qek/baleia.nvim"}), _6_.keys(_7_.group("git", _7_.bind("G", _7_.cmd("Neogit"), _7_.desc("Neogit")), _7_.bind("c", _7_.cmd("Neogit commit"), _7_.desc("Commit")), _7_.bind("l", _7_.cmd("Neogit log"), _7_.desc("Log")))), _6_.opts({graph_style = "unicode", process_spinner = true, commit_editor = {staged_diff_split_kind = "auto"}}), {enabled = false}}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "NeogitOrg/neogit"
  _8_ = spec_24_auto
end
local function _11_(...)
  local _9_ = require("lib.plugins")
  local _10_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_9_.opts({}), _9_.event("VeryLazy"), _9_.keys(_10_.group("git", _10_.bind("b", _10_.cmd("Gitsigns blame_line"), _10_.desc("Blame (line)")), _10_.bind("B", _10_.cmd("Gitsigns blame"), _10_.desc("Blame"))))}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "lewis6991/gitsigns.nvim"
  return spec_24_auto
end
return {_5_, _8_, _11_(...)}
