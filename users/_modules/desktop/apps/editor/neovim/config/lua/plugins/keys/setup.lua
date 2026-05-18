-- [nfnl] fnl/plugins/keys/setup.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_21_auto = {}
local function _3_()
  do
    local name_1_auto = require("which-key")
    local fun_2_auto = name_1_auto.setup
    fun_2_auto(require("plugins.keys._whichkey"))
  end
  return require("plugins.keys._keymap")
end
for __22_auto, attrs_23_auto in ipairs({_1_.lazy(false), _1_.priority(999), _1_.config(_3_)}) do
  for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
    spec_21_auto[key_24_auto] = value_25_auto
  end
end
spec_21_auto[1] = "folke/which-key.nvim"
return spec_21_auto
