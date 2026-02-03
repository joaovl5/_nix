-- [nfnl] fnl/plugins/lsp/completions.fnl
local function _1_()
  vim.g.coq_settings = {auto_start = "shut-up", ["keymap.pre_select"] = true, ["display.preview.border"] = "solid"}
  return nil
end
return {{"ms-jpq/coq_nvim", branch = "coq", build = "COQdeps", init = _1_, lazy = false}}
