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
    return devdocs.ui_call("show")
  end
  local function _11_()
    return devdocs.install_for_filetype()
  end
  local function _12_()
    return devdocs.install_browse()
  end
  local function _13_()
    return devdocs.install_all()
  end
  for __25_auto, attrs_26_auto in ipairs({_6_.deps({"nvim-lua/plenary.nvim", "folke/snacks.nvim", "xieyonn/spinner.nvim"}), _6_.keys(_7_.bind("J", _9_, _7_.desc("Devdocs (Cursor)")), _7_.group("fuzzy", _7_.bind("E", _10_, _7_.desc("Devdocs (Browse)"))), _7_.group("code", _7_.bind("i", _11_, _7_.desc("Devdocs Install (Filetype)")), _7_.bind("I", _12_, _7_.desc("Devdocs Install (Browse)")), _7_.bind("A", _13_, _7_.desc("Devdocs Install (All)")))), _6_.opts({})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "nitaicharan/devdocs.nvim"
  _8_ = spec_24_auto
end
local _16_
do
  local _14_ = require("lib.plugins")
  local _15_ = require("lib.keys")
  local spec_24_auto = {}
  local function _17_()
    local name_1_auto = require("pretty_hover")
    local fun_2_auto = name_1_auto.hover
    return fun_2_auto()
  end
  for __25_auto, attrs_26_auto in ipairs({_14_.event("LspAttach"), _14_.keys(_15_.bind("K", _17_, _15_.desc("Hover"))), _14_.opts({border = "none", wrap = true, multi_server = true, max_width = nil, max_height = nil})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "Fildo7525/pretty_hover"
  _16_ = spec_24_auto
end
local _20_
do
  local _18_ = require("lib.plugins")
  local _19_ = require("lib.keys")
  local spec_24_auto = {}
  local function _21_()
    local name_1_auto = require("tiny-code-action")
    local fun_2_auto = name_1_auto.code_action
    return fun_2_auto()
  end
  for __25_auto, attrs_26_auto in ipairs({_18_.deps({"nvim-lua/plenary.nvim"}), _18_.event("LspAttach"), _18_.keys(_19_.group("code", _19_.bind("a", _21_, _19_.desc("Actions")))), _18_.opts({backend = "delta", picker = "snacks", resolve_timeout = 100, notify = {enabled = true, on_empty = true}, backend_opts = {delta = {header_lines_to_remove = 4, args = {"--line-numbers"}}}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "rachartier/tiny-code-action.nvim"
  _20_ = spec_24_auto
end
local _24_
do
  local _22_ = require("lib.plugins")
  local _23_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_22_.event("VeryLazy"), _22_.deps({{"folke/todo-comments.nvim", cmd = "TodoTrouble", opts = {}}}), _22_.opts({}), _22_.keys(_23_.group("diagnostics", _23_.bind("x", _23_.cmd("Trouble diagnostics toggle"), _23_.desc("Trouble")), _23_.bind("X", _23_.cmd("Trouble diagnostics toggle filter.buf=0"), _23_.desc("Trouble (Buffer)")), _23_.bind("t", _23_.cmd("TodoTrouble"), _23_.desc("TODOs")), _23_.bind("l", _23_.cmd("Trouble loclist toggle"), _23_.desc("Locations")), _23_.bind("q", _23_.cmd("Trouble qflist toggle"), _23_.desc("Quick fixes"))))}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "folke/trouble.nvim"
  _24_ = spec_24_auto
end
return {_3_, _8_, _16_, _20_, _24_, {"MagicDuck/grug-far.nvim", cmd = "GrugFar", opts = {}}}
