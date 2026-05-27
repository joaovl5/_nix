-- [nfnl] fnl/plugins/editor/misc.fnl
local _3_
do
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_1_.lazy(false), _1_.keys(_2_.group("session", _2_.bind("s", _2_.cmd("AutoSession save"), _2_.desc("Save session")), _2_.bind("t", _2_.cmd("AutoSession toggle"), _2_.desc("Toggle autosave")), _2_.bind("f", _2_.cmd("AutoSession search"), _2_.desc("Pick sessions")))), _1_.opts({session_lens = {picker = "snacks"}, cwd_change_handling = true, git_use_branch_name = true, git_auto_restore_on_branch_change = true, bypass_save_filetypes = {"alpha", "dashboard", "snacks_dashboard"}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "rmagatti/auto-session"
  _3_ = spec_24_auto
end
local function _6_(...)
  local _4_ = require("lib.plugins")
  local _5_ = require("lib.keys")
  local spec_24_auto = {}
  local function _7_()
    local name_1_auto = require("zen-mode")
    local fun_2_auto = name_1_auto.toggle
    return fun_2_auto({})
  end
  for __25_auto, attrs_26_auto in ipairs({_4_.keys(_5_.group("window", _5_.bind("z", _7_))), _4_.opts({window = {backdrop = 1, width = 110, height = 1}, plugins = {options = {enabled = true, ruler = true, laststatus = 0, showcmd = false}, twilight = {enabled = false}, gitsigns = {enabled = true}, tmux = {enabled = true}}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "folke/zen-mode.nvim"
  return spec_24_auto
end
return {_3_, _6_(...)}
