-- [nfnl] fnl/plugins/keys/main.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_24_auto = {}
local function _3_()
  do
    local wk = require("which-key")
    local k = require("lib.keys")
    wk.setup(require("plugins.keys._whichkey"))
    k["register-plugin-icons!"]()
  end
  return require("plugins.keys._keymap")
end
for __25_auto, attrs_26_auto in ipairs({_1_.lazy(false), _1_.priority(999), _1_.config(_3_)}) do
  for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
    spec_24_auto[key_27_auto] = value_28_auto
  end
end
spec_24_auto[1] = "folke/which-key.nvim"
return spec_24_auto
