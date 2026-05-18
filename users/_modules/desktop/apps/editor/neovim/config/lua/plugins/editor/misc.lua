-- [nfnl] fnl/plugins/editor/misc.fnl
local function _3_(...)
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_21_auto = {}
  local function _4_()
    local name_1_auto = require("zen-mode")
    local fun_2_auto = name_1_auto.toggle
    return fun_2_auto({})
  end
  for __22_auto, attrs_23_auto in ipairs({_1_.keys(_2_.group("window", _2_.bind("z", _4_))), _1_.opts({window = {backdrop = 1, width = 110, height = 1}, plugins = {options = {enabled = true, ruler = true, laststatus = 0, showcmd = false}, twilight = {enabled = false}, gitsigns = {enabled = true}, tmux = {enabled = true}}})}) do
    for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
      spec_21_auto[key_24_auto] = value_25_auto
    end
  end
  spec_21_auto[1] = "folke/zen-mode.nvim"
  return spec_21_auto
end
return {_3_(...)}
