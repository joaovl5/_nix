-- [nfnl] fnl/plugins/lsp/repl.fnl
local function init_conjure()
  vim.g["conjure#mapping#prefix"] = ","
  return nil
end
init_conjure()
local function _3_(...)
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_23_auto = {}
  local function _6_(...)
    local _4_ = require("lib.plugins")
    local _5_ = require("lib.keys")
    local spec_23_auto0 = {}
    for __24_auto, attrs_25_auto in ipairs({_4_.event("VeryLazy")}) do
      for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
        spec_23_auto0[key_26_auto] = value_27_auto
      end
    end
    spec_23_auto0[1] = "PaterJason/cmp-conjure"
    return spec_23_auto0
  end
  for __24_auto, attrs_25_auto in ipairs({_1_.lazy(false), _1_.keys(_2_.bind(_2_.c("e"), _2_.cmd("ConjureEval"), _2_.m("n", "v"), _2_.desc("Evaluate code")), _2_.group("repl", _2_.bind("l", _2_.cmd("ConjureLogVSplit"), _2_.desc("Show logs")), _2_.bind("o", _2_.cmd("ConjureEvalCurrentForm"), _2_.desc("Eval current form")), _2_.bind("r", _2_.cmd("ConjureEvalRootForm"), _2_.desc("Eval root form")))), _1_.deps(_6_(...))}) do
    for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
      spec_23_auto[key_26_auto] = value_27_auto
    end
  end
  spec_23_auto[1] = "Olical/conjure"
  return spec_23_auto
end
return {_3_(...)}
