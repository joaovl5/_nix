-- [nfnl] fnl/plugins/mini/basics.fnl
local _3_
do
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_21_auto = {}
  for __22_auto, attrs_23_auto in ipairs({_1_.version("*"), _1_.opts(true)}) do
    for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
      spec_21_auto[key_24_auto] = value_25_auto
    end
  end
  spec_21_auto[1] = "nvim-mini/mini.ai"
  _3_ = spec_21_auto
end
local _6_
do
  local _4_ = require("lib.plugins")
  local _5_ = require("lib.keys")
  local spec_21_auto = {}
  local function _7_()
    return MiniBufremove.delete()
  end
  for __22_auto, attrs_23_auto in ipairs({_4_.version("*"), _4_.keys(_5_.group("buffer", _5_.bind("d", _7_, _5_.desc("Delete buffer")))), _4_.opts({silent = true})}) do
    for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
      spec_21_auto[key_24_auto] = value_25_auto
    end
  end
  spec_21_auto[1] = "nvim-mini/mini.bufremove"
  _6_ = spec_21_auto
end
local _10_
do
  local _8_ = require("lib.plugins")
  local _9_ = require("lib.keys")
  local spec_21_auto = {}
  for __22_auto, attrs_23_auto in ipairs({_8_.version("*"), _8_.opts(true)}) do
    for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
      spec_21_auto[key_24_auto] = value_25_auto
    end
  end
  spec_21_auto[1] = "nvim-mini/mini.extra"
  _10_ = spec_21_auto
end
local _13_
do
  local _11_ = require("lib.plugins")
  local _12_ = require("lib.keys")
  local spec_21_auto = {}
  for __22_auto, attrs_23_auto in ipairs({_11_.version("*"), _11_.event("VeryLazy"), _11_.opts({modes = {command = true}})}) do
    for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
      spec_21_auto[key_24_auto] = value_25_auto
    end
  end
  spec_21_auto[1] = "nvim-mini/mini.pairs"
  _13_ = spec_21_auto
end
local _16_
do
  local _14_ = require("lib.plugins")
  local _15_ = require("lib.keys")
  local spec_21_auto = {}
  local function _17_()
    do
      local name_1_auto = require("mini.misc")
      local fun_2_auto = name_1_auto.setup
      fun_2_auto({})
    end
    MiniMisc.setup_restore_cursor()
    return MiniMisc.setup_termbg_sync()
  end
  for __22_auto, attrs_23_auto in ipairs({_14_.version("*"), _14_.config(_17_)}) do
    for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
      spec_21_auto[key_24_auto] = value_25_auto
    end
  end
  spec_21_auto[1] = "nvim-mini/mini.misc"
  _16_ = spec_21_auto
end
local function _20_(...)
  local _18_ = require("lib.plugins")
  local _19_ = require("lib.keys")
  local spec_21_auto = {}
  for __22_auto, attrs_23_auto in ipairs({_18_.lazy(false), _18_.version("*"), _18_.opts({options = {extra_ui = true, win_borders = "solid", basic = false}, mappings = {basic = true, windows = true, move_with_alt = true}})}) do
    for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
      spec_21_auto[key_24_auto] = value_25_auto
    end
  end
  spec_21_auto[1] = "nvim-mini/mini.basics"
  return spec_21_auto
end
return {_3_, _6_, _10_, _13_, _16_, _20_(...)}
