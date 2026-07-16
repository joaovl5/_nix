-- [nfnl] fnl/plugins/lsp/languages/markdown.fnl
local fts = {"markdown", "codecompanion"}
local _3_
do
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_1_.lazy(false)}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "joaovl5/follow-md-links.nvim"
  _3_ = spec_24_auto
end
return {_3_, {"MeanderingProgrammer/render-markdown.nvim", dependencies = {"nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim"}, ft = fts, opts = {completions = {lsp = {enabled = true}}, file_types = fts, overrides = {buftype = {[""] = {enabled = false}}}, render_modes = {"n"}, debounce = 50, preset = "none", restart_highlighter = true, code = {border = "hide", sign = false}, pipe_table = {preset = "none", cell = "trimmed", padding = 0, border_enabled = false, enabled = false}, heading = {setext = true, atx = true, border = true, border_virtual = true, above = "\226\150\129", below = "\226\150\148", border_prefix = true, backgrounds = {"RenderMarkdownH2Bg", "RenderMarkdownH3Bg", "RenderMarkdownH4Bg", "RenderMarkdownH5Bg", "RenderMarkdownH6Bg"}}, indent = {enabled = true, per_level = 2, skip_heading = false}}}, {"tadmccorkle/markdown.nvim", event = "VeryLazy", opts = {mappings = {link_add = "-a", link_follow = "-f", inline_surround_toggle = "-s", inline_surround_toggle_line = "-S", go_curr_heading = "-k", go_parent_heading = "-K", go_next_heading = "-h", go_prev_heading = "-l"}}}}
