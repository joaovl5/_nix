-- [nfnl] fnl/plugins/triforce.fnl
local _local_1_ = require("lib/nvim")
local v_2fn = _local_1_["v/n"]
local v_2flater = _local_1_["v/later"]
local function ln(name, icon)
  return {name = name, icon = icon}
end
local function _4_(...)
  local _2_ = require("lib.plugins")
  local _3_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_2_.deps({"nvzone/volt"}), _2_.event("VeryLazy"), _2_.keys(_3_.group("stats", _3_.bind("t", _3_.cmd("Triforce profile"), _3_.desc("Profile")), _3_.bind("s", _3_.cmd("Triforce stats"), _3_.desc("Stats")), _3_.bind("R", _3_.cmd("Triforce reset"), _3_.desc("Reset")))), _2_.opts({icon_engine = "mini", keymap = {show_profile = nil}, xp_rewards = {char = 4, line = 6, save = 8}, custom_languages = {fennel = ln("Fennel", "\238\154\175 "), nix = ln("Nix", "\239\140\147 "), janet = ln("Janet", "\243\177\129\184 ")}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "gisketch/triforce.nvim"
  return spec_24_auto
end
return {_4_(...)}
