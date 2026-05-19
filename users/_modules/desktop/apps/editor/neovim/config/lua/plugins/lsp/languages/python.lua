-- [nfnl] fnl/plugins/lsp/languages/python.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_23_auto = {}
local function _5_(...)
  local _3_ = require("lib.plugins")
  local _4_ = require("lib.keys")
  local spec_23_auto0 = {}
  for __24_auto, attrs_25_auto in ipairs({_3_.version("*")}) do
    for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
      spec_23_auto0[key_26_auto] = value_27_auto
    end
  end
  spec_23_auto0[1] = "nvim-telescope/telescope.nvim"
  return spec_23_auto0
end
for __24_auto, attrs_25_auto in ipairs({_1_.deps({_5_(...)}), _1_.ft("python"), _1_.keys(_2_.bind(_2_.l("cv"), _2_.cmd("VenvSelect"), _2_.desc("Pick virtual env"))), _1_.opts({})}) do
  for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
    spec_23_auto[key_26_auto] = value_27_auto
  end
end
spec_23_auto[1] = "linux-cultist/venv-selector.nvim"
return spec_23_auto
