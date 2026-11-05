-- [nfnl] fnl/plugins/lsp/misc.fnl
local _local_1_ = require("lib/nvim")
local v_2fautocmd = _local_1_["v/autocmd"]
local function clear_unmatched_highlight()
  return vim.api.nvim_set_hl(0, "BlinkPairsUnmatched", {})
end
local function _2_(_, opts)
  require("blink.pairs").setup(opts)
  clear_unmatched_highlight()
  return v_2fautocmd("ColorScheme", {callback = clear_unmatched_highlight})
end
return {{dir = _G.plugin_dirs["blink-pairs"], name = "blink.pairs", event = "VeryLazy", config = _2_, opts = {mappings = {enabled = true, cmdline = true}, highlights = {enabled = true, cmdline = true, matchparen = {enabled = true, cmdline = true, include_surrounding = false}}}}}
