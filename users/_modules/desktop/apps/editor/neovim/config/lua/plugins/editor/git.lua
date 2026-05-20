-- [nfnl] fnl/plugins/editor/git.fnl
local _local_1_ = require("lib/nvim")
local v_2fn = _local_1_["v/n"]
local v_2flater = _local_1_["v/later"]
local function handle_conf(x)
  do
    local _2_ = require("lib/nvim")
    _2_["v/n"]((tostring("Found ") .. tostring(x.conflicts) .. tostring("conflicts!")))
  end
  local function _3_()
    local name_1_auto = require("resolve")
    local fun_2_auto = name_1_auto.list_conflicts
    return fun_2_auto()
  end
  return v_2flater(_3_)
end
local _6_
do
  local _4_ = require("lib.plugins")
  local _5_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_4_.event({"BufReadPre", "BufNewFile"}), _4_.keys(_5_.group("merge", _5_.bind("j", _5_.cmd("ResolveNext"), _5_.desc("Next Conflict")), _5_.bind("k", _5_.cmd("ResolvePrev"), _5_.desc("Prev Conflict")), _5_.bind("o", _5_.cmd("ResolveOurs"), _5_.desc("Use Ours")), _5_.bind("t", _5_.cmd("ResolveTheirs"), _5_.desc("Use Theirs")), _5_.bind("O", _5_.cmd("ResolveBoth"), _5_.desc("Use Both (ours first)")), _5_.bind("T", _5_.cmd("ResolveBothReverse"), _5_.desc("Use Both (theirs first)")), _5_.bind("b", _5_.cmd("ResolveBase"), _5_.desc("Use base")), _5_.bind("n", _5_.cmd("ResolveNone"), _5_.desc("Use none")), _5_.bind("l", _5_.cmd("ResolveList"), _5_.desc("List conflicts")), _5_.bind("pt", _5_.cmd("ResolveDiffOursTheirs"), _5_.desc("Preview theirs")), _5_.bind("po", _5_.cmd("ResolveDiffTheirsOurs"), _5_.desc("Preview ours")))), _4_.opts({on_conflict_detected = handle_conf, default_keymaps = false})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "spacedentist/resolve.nvim"
  _6_ = spec_24_auto
end
local _9_
do
  local _7_ = require("lib.plugins")
  local _8_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_7_.cmd("Neogit"), _7_.deps({"esmuellert/codediff.nvim", "m00qek/baleia.nvim"}), _7_.keys(_8_.group("git", _8_.bind("G", _8_.cmd("Neogit"), _8_.desc("Neogit")), _8_.bind("c", _8_.cmd("Neogit commit"), _8_.desc("Commit")), _8_.bind("l", _8_.cmd("Neogit log"), _8_.desc("Log")))), _7_.opts({graph_style = "unicode", process_spinner = true, commit_editor = {staged_diff_split_kind = "auto"}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "NeogitOrg/neogit"
  _9_ = spec_24_auto
end
local function _12_(...)
  local _10_ = require("lib.plugins")
  local _11_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_10_.opts({}), _10_.event("VeryLazy"), _10_.keys(_11_.group("git", _11_.bind("b", _11_.cmd("Gitsigns blame_line"), _11_.desc("Blame (line)")), _11_.bind("B", _11_.cmd("Gitsigns blame"), _11_.desc("Blame"))))}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "lewis6991/gitsigns.nvim"
  return spec_24_auto
end
return {_6_, _9_, _12_(...)}
