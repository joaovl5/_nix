-- [nfnl] fnl/plugins/editor/paredit.fnl
local fts = {"fennel"}
local function pe(name, ...)
  local name_1_auto = require("nvim-paredit.api")
  local fun_2_auto = name_1_auto[name]
  return fun_2_auto(...)
end
do
  local _1_ = require("lib.keys")
  local function _2_()
    return pe("slurp_forwards")
  end
  local function _3_()
    return pe("slurp_backwards")
  end
  local function _4_()
    return pe("barf_forwards")
  end
  local function _5_()
    return pe("barf_backwards")
  end
  local function _6_()
    return pe("drag_element_forwards")
  end
  local function _7_()
    return pe("drag_element_backwards")
  end
  local function _8_()
    return pe("drag_pair_forwards")
  end
  local function _9_()
    return pe("drag_pair_backwards")
  end
  local function _10_()
    return pe("drag_form_forwards")
  end
  local function _11_()
    return pe("drag_form_backwards")
  end
  local function _12_()
    return pe("raise_form")
  end
  local function _13_()
    return pe("raise_element")
  end
  local function _14_()
    return pe("move_to_next_element_tail")
  end
  local function _15_()
    return pe("move_to_next_element_head")
  end
  local function _16_()
    return pe("move_to_prev_element_head")
  end
  local function _17_()
    return pe("move_to_prev_element_tail")
  end
  local function _18_()
    return pe("move_to_parent_form_start")
  end
  local function _19_()
    return pe("move_to_parent_form_end")
  end
  local function _20_()
    return pe("move_to_top_level_form_head")
  end
  local function _21_()
    return pe("select_around_form")
  end
  local function _22_()
    return pe("select_in_form")
  end
  local function _23_()
    return pe("select_in_top_level_form")
  end
  local function _24_()
    return pe("select_element")
  end
  local function _25_()
    return pe("select_element")
  end
  _1_["ft-keys"](fts, _1_.specs(_1_.bind(">l", _2_, _1_.desc("Slurp forwards")), _1_.bind(">h", _3_, _1_.desc("Slurp backwards")), _1_.bind("<l", _4_, _1_.desc("Barf forwards")), _1_.bind("<h", _5_, _1_.desc("Barf backwards")), _1_.bind(">e", _6_, _1_.desc("Drag element forwards")), _1_.bind("<e", _7_, _1_.desc("Drag element backwards")), _1_.bind(">p", _8_, _1_.desc("Drag pair forwards")), _1_.bind("<p", _9_, _1_.desc("Drag pair backwards")), _1_.bind(">f", _10_, _1_.desc("Drag form forwards")), _1_.bind("<f", _11_, _1_.desc("Drag form backwards")), _1_.bind("^f", _12_, _1_.desc("Raise form")), _1_.bind("^e", _13_, _1_.desc("Raise element")), _1_["with-mode"]({"n", "x", "o", "v"}, _1_.bind("E", _14_, _1_.desc("Jump to next el. tail")), _1_.bind("W", _15_, _1_.desc("Jump to next el. head")), _1_.bind("B", _16_, _1_.desc("Jump to prev el. head")), _1_.bind("gE", _17_, _1_.desc("Jump to prev el. tail"))), _1_["with-mode"]({"n", "x", "v"}, _1_.bind("(", _18_, _1_.desc("Go to parent head")), _1_.bind(")", _19_, _1_.desc("Go to parent tail")), _1_.bind("T", _20_, _1_.desc("Go to top-level head"))), _1_["with-mode"]({"o", "v"}, _1_.bind("af", _21_, _1_.desc("Around form")), _1_.bind("if", _22_, _1_.desc("In form")), _1_.bind("aF", _23_, _1_.desc("In top-level form")), _1_.bind("ae", _24_, _1_.desc("Around element")), _1_.bind("ie", _25_, _1_.desc("In element")))))
end
local _26_ = require("lib.plugins")
local _27_ = require("lib.keys")
local spec_24_auto = {}
for __25_auto, attrs_26_auto in ipairs({_26_.event("VeryLazy"), _26_.opts({use_default_keys = false})}) do
  for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
    spec_24_auto[key_27_auto] = value_28_auto
  end
end
spec_24_auto[1] = "julienvincent/nvim-paredit"
return spec_24_auto
