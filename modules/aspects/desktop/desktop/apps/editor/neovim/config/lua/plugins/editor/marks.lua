-- [nfnl] fnl/plugins/editor/marks.fnl
local function _3_(...)
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_24_auto = {}
  local function _4_()
    local name_1_auto = require("recall.snacks")
    local fun_2_auto = name_1_auto.pick
    return fun_2_auto()
  end
  for __25_auto, attrs_26_auto in ipairs({_1_.keys(_2_.group("marks", _2_.bind("t", _2_.cmd("RecallToggle"), _2_.desc("Toggle mark")), _2_.bind("l", _2_.cmd("RecallNext"), _2_.desc("Next mark")), _2_.bind("h", _2_.cmd("RecallPrevious"), _2_.desc("Prev mark")), _2_.bind("c", _2_.cmd("RecallClear"), _2_.desc("Clear all mark")), _2_.bind(":f", _4_, _2_.desc("Pick marks")))), _1_.opts({sign = "\239\145\161"})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "fnune/recall.nvim"
  return spec_24_auto
end
return {_3_(...)}
