-- [nfnl] fnl/plugins/editor/motions.fnl
local _local_1_ = require("lib/nvim")
local v_2f_24 = _local_1_["v/$"]
local function treewalker(subcommand)
  local ok, err = pcall(v_2f_24, ("Treewalker " .. subcommand))
  if not ok then
    if (("string" == type(err)) and string.find(err, "Treewalker: Treesitter node not found under cursor", 1, true)) then
      return vim.notify("Treewalker: no Treesitter node under cursor", vim.log.levels.WARN)
    else
      return error(err)
    end
  else
    return nil
  end
end
local _6_
do
  local _4_ = require("lib.plugins")
  local _5_ = require("lib.keys")
  local spec_23_auto = {}
  local function _7_()
    local name_1_auto = require("flash")
    local fun_2_auto = name_1_auto.jump
    return fun_2_auto()
  end
  local function _8_()
    local name_1_auto = require("flash")
    local fun_2_auto = name_1_auto.treesitter
    return fun_2_auto()
  end
  local function _9_()
    local name_1_auto = require("flash")
    local fun_2_auto = name_1_auto.remote
    return fun_2_auto()
  end
  local function _10_(...)
    local keys = "fhdjskalgrueiwoqptvnmb"
    return {labels = keys, search = {forward = true, wrap = true, mode = "fuzzy", multi_window = false}, jump = {nohlsearch = true, autojump = true}, label = {distance = true, uppercase = false}, highlight = {backdrop = true}, modes = {char = {enabled = false}, treesitter = {labels = keys, highlight = {backdrop = true, matches = false}}}}
  end
  for __24_auto, attrs_25_auto in ipairs({_4_.event("BufEnter"), _4_.keys(_5_.bind("s", _7_, _5_.m("n", "x", "o")), _5_.bind("S", _8_, _5_.m("n", "x", "o")), _5_.bind("r", _9_, _5_.m("o"), _5_.desc("Remote flash"))), _4_.opts(_10_(...))}) do
    for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
      spec_23_auto[key_26_auto] = value_27_auto
    end
  end
  spec_23_auto[1] = "folke/flash.nvim"
  _6_ = spec_23_auto
end
local _13_
do
  local _11_ = require("lib.plugins")
  local _12_ = require("lib.keys")
  local spec_23_auto = {}
  local function _14_()
    local name_1_auto = require("spider")
    local fun_2_auto = name_1_auto.motion
    return fun_2_auto("w")
  end
  local function _15_()
    local name_1_auto = require("spider")
    local fun_2_auto = name_1_auto.motion
    return fun_2_auto("e")
  end
  local function _16_()
    local name_1_auto = require("spider")
    local fun_2_auto = name_1_auto.motion
    return fun_2_auto("b")
  end
  for __24_auto, attrs_25_auto in ipairs({_11_.keys(_12_.bind("w", _14_, _12_.m("n", "x", "o")), _12_.bind("e", _15_, _12_.m("n", "x", "o")), _12_.bind("b", _16_, _12_.m("n", "x", "o"))), _11_.opts(true)}) do
    for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
      spec_23_auto[key_26_auto] = value_27_auto
    end
  end
  spec_23_auto[1] = "chrisgrieser/nvim-spider"
  _13_ = spec_23_auto
end
local function _19_(...)
  local _17_ = require("lib.plugins")
  local _18_ = require("lib.keys")
  local spec_23_auto = {}
  local function _20_()
    return treewalker("Left")
  end
  local function _21_()
    return treewalker("Right")
  end
  local function _22_()
    return treewalker("Up")
  end
  local function _23_()
    return treewalker("Down")
  end
  local function _24_()
    return treewalker("SwapLeft")
  end
  local function _25_()
    return treewalker("SwapRight")
  end
  local function _26_()
    return treewalker("SwapUp")
  end
  local function _27_()
    return treewalker("SwapDown")
  end
  for __24_auto, attrs_25_auto in ipairs({_17_.cmd("Treewalker"), _17_.keys(_18_.bind("<A-[>", _20_, _18_.m("n", "x")), _18_.bind("<A-]>", _21_, _18_.m("n", "x")), _18_.bind("<A-k>", _22_, _18_.m("n", "x")), _18_.bind("<A-j>", _23_, _18_.m("n", "x")), _18_.bind("<A-S-[>", _24_, _18_.m("n", "x")), _18_.bind("<A-S-]>", _25_, _18_.m("n", "x")), _18_.bind("<A-K>", _26_, _18_.m("n", "x")), _18_.bind("<A-J>", _27_, _18_.m("n", "x"))), _17_.opts({})}) do
    for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
      spec_23_auto[key_26_auto] = value_27_auto
    end
  end
  spec_23_auto[1] = "aaronik/treewalker.nvim"
  return spec_23_auto
end
return {{"mluders/comfy-line-numbers.nvim", opts = true, event = "BufEnter"}, _6_, _13_, _19_(...)}
