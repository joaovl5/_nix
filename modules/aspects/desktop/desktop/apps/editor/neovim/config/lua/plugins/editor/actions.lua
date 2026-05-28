-- [nfnl] fnl/plugins/editor/actions.fnl
local _3_
do
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_24_auto = {}
  local function _4_()
    local name_1_auto = require("neogen")
    local fun_2_auto = name_1_auto.jump_next
    return fun_2_auto()
  end
  local function _5_()
    local name_1_auto = require("neogen")
    local fun_2_auto = name_1_auto.jump_prev
    return fun_2_auto()
  end
  for __25_auto, attrs_26_auto in ipairs({_1_.cmd("Neogen"), _1_.keys(_2_.bind(_2_.c("l"), _4_, _2_.m("i")), _2_.bind(_2_.c("h"), _5_, _2_.m("i")), _2_.group("code", _2_.bind("g", _2_.cmd("Neogen"), _2_.desc("Neogen")))), _1_.opts({enabled = true, languages = {python = {template = {annotation_convention = "google_docstrings"}}}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "danymat/neogen"
  _3_ = spec_24_auto
end
local _8_
do
  local _6_ = require("lib.plugins")
  local _7_ = require("lib.keys")
  local spec_24_auto = {}
  local function _9_()
    local name_1_auto = require("pretty_hover")
    local fun_2_auto = name_1_auto.hover
    return fun_2_auto()
  end
  for __25_auto, attrs_26_auto in ipairs({_6_.event("LspAttach"), _6_.keys(_7_.bind("K", _9_, _7_.desc("Hover"))), _6_.opts({border = "none", wrap = true, multi_server = true, max_width = nil, max_height = nil})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "Fildo7525/pretty_hover"
  _8_ = spec_24_auto
end
local _12_
do
  local _10_ = require("lib.plugins")
  local _11_ = require("lib.keys")
  local spec_24_auto = {}
  local function _13_()
    local name_1_auto = require("tiny-code-action")
    local fun_2_auto = name_1_auto.code_action
    return fun_2_auto()
  end
  for __25_auto, attrs_26_auto in ipairs({_10_.deps({"nvim-lua/plenary.nvim"}), _10_.event("LspAttach"), _10_.keys(_11_.group("code", _11_.bind("a", _13_, _11_.desc("Actions")))), _10_.opts({backend = "delta", picker = "snacks", resolve_timeout = 100, notify = {enabled = true, on_empty = true}, backend_opts = {delta = {header_lines_to_remove = 4, args = {"--line-numbers"}}}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "rachartier/tiny-code-action.nvim"
  _12_ = spec_24_auto
end
local _16_
do
  local _14_ = require("lib.plugins")
  local _15_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_14_.cmd("Trouble"), _14_.deps({{"folke/todo-comments.nvim", cmd = "TodoTrouble", opts = {}}}), _14_.opts({}), _14_.keys(_15_.group("diagnostics", _15_.bind("x", _15_.cmd("Trouble diagnostics toggle"), _15_.desc("Trouble")), _15_.bind("X", _15_.cmd("Trouble diagnostics toggle filter.buf=0"), _15_.desc("Trouble (Buffer)")), _15_.bind("t", _15_.cmd("TodoTrouble"), _15_.desc("TODOs")), _15_.bind("l", _15_.cmd("Trouble loclist toggle"), _15_.desc("Locations")), _15_.bind("q", _15_.cmd("Trouble qflist toggle"), _15_.desc("Quick fixes"))))}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "folke/trouble.nvim"
  _16_ = spec_24_auto
end
return {_3_, _8_, _12_, _16_, {"MagicDuck/grug-far.nvim", cmd = "GrugFar", opts = {}}}
