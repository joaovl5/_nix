-- [nfnl] fnl/plugins/editor/views.fnl
local _3_
do
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_23_auto = {}
  for __24_auto, attrs_25_auto in ipairs({_1_.cmd("Glance"), _1_.keys(_2_.bind("gI", _2_.cmd("Glance implementations"), _2_.desc("Implementations")), _2_.bind("gr", _2_.cmd("Glance references"), _2_.desc("References")), _2_.bind("gd", _2_.cmd("Glance definitions"), _2_.desc("Definitions")), _2_.bind("gt", _2_.cmd("Glance type_definitions"), _2_.desc("Type Definitions")))}) do
    for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
      spec_23_auto[key_26_auto] = value_27_auto
    end
  end
  spec_23_auto[1] = "dnhlc/glance.nvim"
  _3_ = spec_23_auto
end
local function _6_(...)
  local _4_ = require("lib.plugins")
  local _5_ = require("lib.keys")
  local spec_23_auto = {}
  for __24_auto, attrs_25_auto in ipairs({_4_.deps({"SmiteshP/nvim-navic", "MunifTanjim/nui.nvim", "numToStr/Comment.nvim"}), _4_.cmd("Navbuddy"), _4_.keys(_5_.group("code", _5_.bind("n", _5_.cmd("Navbuddy"), _5_.desc("Navbuddy")))), _4_.opts({window = {border = "rounded", size = "60%"}, lsp = {auto_attach = true}})}) do
    for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
      spec_23_auto[key_26_auto] = value_27_auto
    end
  end
  spec_23_auto[1] = "SmiteshP/nvim-navbuddy"
  return spec_23_auto
end
return {{"dnlhc/glance.nvim", cmd = "Glance"}, _3_, _6_(...)}
