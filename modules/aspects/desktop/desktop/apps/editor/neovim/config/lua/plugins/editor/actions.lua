-- [nfnl] fnl/plugins/editor/actions.fnl
local devdocs = require("plugins.editor._devdocs")
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
    return devdocs.cursor_lookup()
  end
  local function _10_()
    return devdocs.selection_lookup()
  end
  local function _11_()
    return devdocs.ui_call("show")
  end
  local function _12_()
    return devdocs.install_for_filetype()
  end
  local function _13_()
    return devdocs.install_browse()
  end
  local function _14_()
    return devdocs.install_all()
  end
  for __25_auto, attrs_26_auto in ipairs({_6_.deps({"nvim-lua/plenary.nvim", "folke/snacks.nvim", "xieyonn/spinner.nvim"}), _6_.keys(_7_.bind("J", _9_, _7_.desc("Devdocs (Cursor)")), _7_.bind("J", _10_, _7_.desc("Devdocs (Selection)"), _7_.m("x")), _7_.group("fuzzy", _7_.bind("E", _11_, _7_.desc("Devdocs (Browse)"))), _7_.group("code", _7_.bind("i", _12_, _7_.desc("Devdocs Install (Filetype)")), _7_.bind("I", _13_, _7_.desc("Devdocs Install (Browse)")), _7_.bind("A", _14_, _7_.desc("Devdocs Install (All)")))), _6_.opts({})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "nitaicharan/devdocs.nvim"
  _8_ = spec_24_auto
end
local _17_
do
  local _15_ = require("lib.plugins")
  local _16_ = require("lib.keys")
  local spec_24_auto = {}
  local function _18_()
    local name_1_auto = require("pretty_hover")
    local fun_2_auto = name_1_auto.hover
    return fun_2_auto()
  end
  for __25_auto, attrs_26_auto in ipairs({_15_.event("LspAttach"), _15_.keys(_16_.bind("K", _18_, _16_.desc("Hover"))), _15_.opts({border = "none", wrap = true, multi_server = true, max_width = nil, max_height = nil})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "Fildo7525/pretty_hover"
  _17_ = spec_24_auto
end
local _21_
do
  local _19_ = require("lib.plugins")
  local _20_ = require("lib.keys")
  local spec_24_auto = {}
  local function _22_()
    local name_1_auto = require("tiny-code-action")
    local fun_2_auto = name_1_auto.code_action
    return fun_2_auto()
  end
  for __25_auto, attrs_26_auto in ipairs({_19_.deps({"nvim-lua/plenary.nvim"}), _19_.event("LspAttach"), _19_.keys(_20_.group("code", _20_.bind("a", _22_, _20_.desc("Actions")))), _19_.opts({backend = "delta", picker = "snacks", resolve_timeout = 100, notify = {enabled = true, on_empty = true}, backend_opts = {delta = {header_lines_to_remove = 4, args = {"--line-numbers"}}}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "rachartier/tiny-code-action.nvim"
  _21_ = spec_24_auto
end
local _25_
do
  local _23_ = require("lib.plugins")
  local _24_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_23_.event("VeryLazy"), _23_.deps({{"folke/todo-comments.nvim", cmd = "TodoTrouble", opts = {}}}), _23_.opts({}), _23_.keys(_24_.group("diagnostics", _24_.bind("x", _24_.cmd("Trouble diagnostics toggle"), _24_.desc("Trouble")), _24_.bind("X", _24_.cmd("Trouble diagnostics toggle filter.buf=0"), _24_.desc("Trouble (Buffer)")), _24_.bind("t", _24_.cmd("TodoTrouble"), _24_.desc("TODOs")), _24_.bind("l", _24_.cmd("Trouble loclist toggle"), _24_.desc("Locations")), _24_.bind("q", _24_.cmd("Trouble qflist toggle"), _24_.desc("Quick fixes"))))}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "folke/trouble.nvim"
  _25_ = spec_24_auto
end
return {_3_, _8_, _17_, _21_, _25_, {"MagicDuck/grug-far.nvim", cmd = "GrugFar", opts = {}}}
