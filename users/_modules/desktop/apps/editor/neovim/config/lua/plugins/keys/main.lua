-- [nfnl] fnl/plugins/keys/main.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_23_auto = {}
local function _3_()
  do
    local wk = require("which-key")
    local k = require("lib.keys")
    wk.setup(require("plugins.keys._whichkey"))
    k["register-plugin-icons!"]()
  end
  return require("plugins.keys._keymap")
end
for __24_auto, attrs_25_auto in ipairs({_1_.lazy(false), _1_.priority(999), _1_.config(_3_)}) do
  for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
    spec_23_auto[key_26_auto] = value_27_auto
  end
end
spec_23_auto[1] = "folke/which-key.nvim"
return spec_23_auto
