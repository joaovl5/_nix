-- [nfnl] fnl/plugins/ui/noice.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_21_auto = {}
for __22_auto, attrs_23_auto in ipairs({_1_.lazy(false), _1_.deps({"MunifTanjim/nui.nvim"}), _1_.keys(_2_.group("diagnostics", _2_.bind("m", _2_.cmd("NoiceAll"), _2_.desc("Messages")))), _1_.opts({views = {cmdline_popup = {border = {style = "none"}, padding = {1, 1}, position = {row = 19, col = "60%"}}, filter_options = {}, win_options = {winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder"}}, popupmenu = {relative = "editor", position = {row = 19, col = "50%"}, size = {width = 60, height = 10}, border = {style = "solid", padding = {0, 1}}, win_options = {winhighlight = {Normal = "Normal", FloatBorder = "DiagnosticInfo"}}}, lsp = {override = {["vim.lsp.util.convert_input_to_markdown_lines"] = true, ["vim.lsp.util.stylize_markdown"] = true, ["cmp.entry.get_documentation"] = true}}, cmdline = {enabled = true, view = "cmdline_popup"}, presets = {bottom_search = true, long_message_to_split = true, command_palette = false, inc_rename = false, lsp_doc_border = false}})}) do
  for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
    spec_21_auto[key_24_auto] = value_25_auto
  end
end
spec_21_auto[1] = "folke/noice.nvim"
return spec_21_auto
