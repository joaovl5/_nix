-- [nfnl] fnl/plugins/indent.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_21_auto = {}
local function _3_()
  local hk = require("ibl.hooks")
  local hl_setup = hk.type.HIGHLIGHT_SETUP
  local set_hl
  local function _4_(_241, _242)
    return vim.api.nvim_set_hl(0, _241, {fg = _242})
  end
  set_hl = _4_
  local bg_hl = "DimDim"
  local hl = "RainbowViolet"
  local function _5_()
    set_hl("RainbowViolet", "#AB94FC")
    return set_hl("DimDim", "#303030")
  end
  hk.register(hl_setup, _5_)
  return {indent = {highlight = bg_hl, char = "\226\139\174"}, scope = {highlight = hl, char = "\226\139\174", show_exact_scope = true}}
end
for __22_auto, attrs_23_auto in ipairs({_1_.main("ibl"), _1_.event("BufEnter"), _1_.opts(_3_)}) do
  for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
    spec_21_auto[key_24_auto] = value_25_auto
  end
end
spec_21_auto[1] = "lukas-reineke/indent-blankline.nvim"
return spec_21_auto
