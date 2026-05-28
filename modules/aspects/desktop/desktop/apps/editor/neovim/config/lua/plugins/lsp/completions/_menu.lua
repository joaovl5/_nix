-- [nfnl] fnl/plugins/lsp/completions/_menu.fnl
local function _1_(comp_icon, comp_kind)
  return {border = "none", min_width = 40, scrolloff = 6, direction_priority = {"s", "n"}, auto_show = true, auto_show_delay_ms = 0, draw = {padding = 0, gap = 1, components = {kind_icon = comp_icon, kind = comp_kind}, columns = {{"kind_icon", "kind", gap = 1}, {"label", gap = 1}}}}
end
return _1_
