-- [nfnl] fnl/plugins/lsp/languages/python.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_21_auto = {}
local function _5_(...)
  local _3_ = require("lib.plugins")
  local _4_ = require("lib.keys")
  local spec_21_auto0 = {}
  for __22_auto, attrs_23_auto in ipairs({_3_.version("*")}) do
    for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
      spec_21_auto0[key_24_auto] = value_25_auto
    end
  end
  spec_21_auto0[1] = "nvim-telescope/telescope.nvim"
  return spec_21_auto0
end
for __22_auto, attrs_23_auto in ipairs({_1_.deps({_5_(...)}), _1_.ft("python"), _1_.keys(_2_.bind(_2_.l("cv"), _2_.cmd("VenvSelect"), _2_.desc("Pick virtual env"))), _1_.opts({})}) do
  for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
    spec_21_auto[key_24_auto] = value_25_auto
  end
end
spec_21_auto[1] = "linux-cultist/venv-selector.nvim"
return spec_21_auto
