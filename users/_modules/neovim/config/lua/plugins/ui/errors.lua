-- [nfnl] fnl/plugins/ui/errors.fnl
local function _1_()
  do
    local name_2_auto = require("tiny-inline-diagnostic")
    local fun_3_auto = name_2_auto.setup
    fun_3_auto({preset = "powerline", options = {multilines = {enabled = true}, breakline = {enabled = true}, show_all_diags_on_cursorline = true, override_open_float = true, severity = {vim.diagnostic.severity.ERROR}, show_diags_only_under_cursor = false}})
  end
  return vim.diagnostic.config({virtual_text = false})
end
return {"rachartier/tiny-inline-diagnostic.nvim", event = "VeryLazy", priority = 1000, config = _1_}
