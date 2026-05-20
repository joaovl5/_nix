-- [nfnl] fnl/plugins/lsp/languages/python.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_24_auto = {}
local function _5_(...)
  local _3_ = require("lib.plugins")
  local _4_ = require("lib.keys")
  local spec_24_auto0 = {}
  for __25_auto, attrs_26_auto in ipairs({_3_.version("*")}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto0[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto0[1] = "nvim-telescope/telescope.nvim"
  return spec_24_auto0
end
for __25_auto, attrs_26_auto in ipairs({_1_.deps({_5_(...)}), _1_.ft("python"), _1_.keys(_2_.bind(_2_.l("cv"), _2_.cmd("VenvSelect"), _2_.desc("Pick virtual env"))), _1_.opts({})}) do
  for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
    spec_24_auto[key_27_auto] = value_28_auto
  end
end
spec_24_auto[1] = "linux-cultist/venv-selector.nvim"
return spec_24_auto
