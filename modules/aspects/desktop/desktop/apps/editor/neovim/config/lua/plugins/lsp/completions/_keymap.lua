-- [nfnl] fnl/plugins/lsp/completions/_keymap.fnl
local function _1_(cmp)
  if cmp.snippet_active() then
    return cmp.accept()
  else
    return cmp.select_and_accept()
  end
end
return {preset = "none", ["<Tab>"] = {_1_, "snippet_forward", "fallback"}, ["<S-Tab>"] = {"snippet_backward", "fallback"}, ["<A-j>"] = {"select_next"}, ["<A-k>"] = {"select_prev"}, ["<C-d>"] = {"scroll_documentation_down"}, ["<C-u>"] = {"scroll_documentation_up"}, ["<C-k>"] = {"show_signature", "hide_signature"}}
