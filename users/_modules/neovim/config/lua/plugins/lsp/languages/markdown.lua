-- [nfnl] fnl/plugins/lsp/languages/markdown.fnl
local filetypes = {"markdown", "Avante"}
local function _1_()
  local presets = require("markview.presets")
  do
    local name_2_auto = require("markview")
    local fun_3_auto = name_2_auto.setup
    fun_3_auto({markdown = {headings = presets.headings.slanted, tables = presets.tables.rounded}})
  end
  local name_2_auto = require("markview")
  local fun_3_auto = name_2_auto.setup
  return fun_3_auto({preview = {filetypes = filetypes, icon_provider = "mini"}, markdown = {list_items = {wrap = true, shift_width = 2, marker_minus = {text = "\226\137\149", wrap = true, add_padding = false}}}})
end
return {"OXY2DEV/markview.nvim", ft = filetypes, config = _1_}
