-- [nfnl] fnl/plugins/lsp/completions/_menu.fnl
local function _1_(comp_icon, comp_kind, comp_label)
  return {border = "none", min_width = 30, scrolloff = 4, direction_priority = {"s", "n"}, auto_show = true, auto_show_delay_ms = 5, draw = {padding = 1, gap = 1, components = {label = comp_label, kind_icon = comp_icon, kind = comp_kind}, columns = {{"kind_icon", "kind", gap = 1}, {"label", gap = 1}}}}
end
return _1_
