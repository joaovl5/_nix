-- [nfnl] fnl/plugins/editor/misc.fnl
local _3_
do
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_1_.event("BufEnter"), _1_.opts({cursor_scrolls_alone = false})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "karb94/neoscroll.nvim"
  _3_ = spec_24_auto
end
local _6_
do
  local _4_ = require("lib.plugins")
  local _5_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_4_.event("BufEnter"), _4_.opts({stiffness = 0.8, stiffness_insert_mode = 0.7, trailing_stiffness = 0.6, trailing_stiffness_insert_mode = 0.7, damping = 0.95, damping_insert_mode = 0.95, distance_stop_animating = 0.5, time_interval = 7})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "sphamba/smear-cursor.nvim"
  _6_ = spec_24_auto
end
local function _9_(...)
  local _7_ = require("lib.plugins")
  local _8_ = require("lib.keys")
  local spec_24_auto = {}
  local function _10_()
    local name_1_auto = require("zen-mode")
    local fun_2_auto = name_1_auto.toggle
    return fun_2_auto({})
  end
  for __25_auto, attrs_26_auto in ipairs({_7_.keys(_8_.group("window", _8_.bind("z", _10_))), _7_.opts({window = {backdrop = 1, width = 110, height = 1}, plugins = {options = {enabled = true, ruler = true, laststatus = 0, showcmd = false}, twilight = {enabled = false}, gitsigns = {enabled = true}, tmux = {enabled = true}}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "folke/zen-mode.nvim"
  return spec_24_auto
end
return {_3_, _6_, _9_(...)}
