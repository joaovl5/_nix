-- [nfnl] fnl/plugins/lsp/completions.fnl
local function setup_blink()
  local blink = require("blink.cmp")
  local colorful_menu = require("colorful-menu")
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
  local _cm_text
  local function _6_(ctx)
    return colorful_menu.blink_components_text(ctx)
  end
  _cm_text = _6_
  local _cm_hl
  local function _7_(ctx)
    return colorful_menu.blink_components_highlight(ctx)
  end
  _cm_hl = _7_
  local comp_icon = {text = _icon, highlight = _icon_hl}
  local comp_kind = {highlight = _icon_hl}
  local comp_label = {text = _cm_text, highlight = _cm_hl}
  local function _8_(cmp)
    if cmp.snippet_active() then
      return cmp.accept()
    else
      return cmp.select_and_accept()
    end
  end
  local _10_
  do
    local sources = {"lsp", "path", "snippets", "buffer"}
    local debug_sources = {"dap", "lsp", "path", "snippets", "buffer"}
    local function _11_()
      local name_2_auto = require("cmp_dap")
      local fun_3_auto = name_2_auto.is_dap_buffer
      return fun_3_auto()
    end
    _10_ = {default = sources, per_filetype = {["dap-repl"] = debug_sources, ["dap-view"] = debug_sources}, providers = {dap = {name = "dap", module = "blink.compat.sources", enabled = _11_}}}
  end
  return blink.setup({keymap = {preset = "none", ["<Tab>"] = {_8_, "snippet_forward", "fallback"}, ["<S-Tab>"] = {"snippet_backward", "fallback"}, ["<A-j>"] = {"select_next"}, ["<A-k>"] = {"select_prev"}, ["<C-d>"] = {"scroll_documentation_down"}, ["<C-u>"] = {"scroll_documentation_up"}, ["<C-k>"] = {"show_signature", "hide_signature"}}, appearance = {nerd_font_variant = "mono"}, completion = {ghost_text = {enabled = true}, keyword = {range = "full"}, accept = {auto_brackets = {enabled = false}}, list = {selection = {preselect = true}}, documentation = {auto_show = true, auto_show_delay_ms = 0, window = {border = "none", direction_priority = {menu_south = {"e", "w", "s"}, menu_north = {"e", "w", "n"}}}}, menu = {border = "none", min_width = 30, scrolloff = 4, direction_priority = {"s", "n"}, auto_show = true, auto_show_delay_ms = 5, draw = {padding = 1, gap = 1, components = {label = comp_label, kind_icon = comp_icon, kind = comp_kind}, columns = {{"kind_icon", "kind", gap = 1}, {"label", gap = 1}}}}}, sources = _10_, signature = {enabled = true, trigger = {show_on_keyword = true, show_on_insert = true}, window = {min_width = 1, max_width = 200, max_height = 30, border = "none"}}, cmdline = {keymap = {preset = "inherit"}, completion = {menu = {auto_show = true}}}, fuzzy = {sorts = {"exact", "score", "sort_text"}, implementation = "prefer_rust_with_warning"}})
end
return {{dir = _G.plugin_dirs["blink-cmp"], event = "InsertEnter", config = setup_blink, dependencies = {{"saghen/blink.compat", lazy = true}}}}
