-- [nfnl] fnl/plugins/lsp/completions/setup.fnl
local function get_blink_config(comp_icon, comp_kind)
  local documentation = require("plugins.lsp.completions._documentation")
  local keymap = require("plugins.lsp.completions._keymap")
  local kind_icons = require("plugins.lsp.completions._icons")
  local menu = require("plugins.lsp.completions._menu")
  local signature = require("plugins.lsp.completions._signature")
  local sources = require("plugins.lsp.completions._sources")
  return {keymap = keymap, appearance = {nerd_font_variant = "mono", kind_icons = kind_icons}, completion = {ghost_text = {enabled = false}, keyword = {range = "full"}, accept = {auto_brackets = {enabled = false}}, list = {selection = {preselect = true}, max_items = 250}, documentation = documentation, menu = menu(comp_icon, comp_kind)}, sources = sources, signature = signature, cmdline = {keymap = {preset = "inherit"}, sources = {"buffer", "cmdline"}, completion = {menu = {auto_show = true}}}, fuzzy = {sorts = {"exact", "score", "sort_text"}, implementation = "prefer_rust_with_warning"}}
end
local function setup_blink()
  local blink = require("blink.cmp")
  local mini_icons = require("mini.icons")
  local _icon_data
  local function _1_(ctx)
    return mini_icons.get("lsp", ctx.kind)
  end
  _icon_data = _1_
  local _icon_hl
  local function _2_(ctx)
    local _let_3_ = _icon_data(ctx)
    local _ = _let_3_[1]
    local hl = _let_3_[2]
    local _0 = _let_3_[3]
    return (hl or ctx.kind_hl)
  end
  _icon_hl = _2_
  local _icon
  local function _4_(ctx)
    local _let_5_ = _icon_data(ctx)
    local icon = _let_5_[1]
    local _ = _let_5_[2]
    local _0 = _let_5_[3]
    return ((icon or ctx.kind_icon) .. ctx.icon_gap)
  end
  _icon = _4_
  local comp_icon = {text = _icon, highlight = _icon_hl}
  local comp_kind = {highlight = _icon_hl}
  return blink.setup(get_blink_config(comp_icon, comp_kind))
end
return {{dir = _G.plugin_dirs["blink-cmp"], event = "InsertEnter", config = setup_blink, dependencies = {{"saghen/blink.compat", lazy = true}, {"mikavilpas/blink-ripgrep.nvim", version = "*"}, "saghen/blink.lib", "bydlw98/blink-cmp-env", "Kaiser-Yang/blink-cmp-git", "disrupted/blink-cmp-conventional-commits"}}}
