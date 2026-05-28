-- [nfnl] fnl/plugins/lsp/misc.fnl
local _3_
do
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({_1_.event("VeryLazy"), _1_.opts({wakeup_delay = 500, grace_period = (60 * 10)})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "zeioth/garbage-day.nvim"
  _3_ = spec_24_auto
end
return {_3_, {dir = _G.plugin_dirs["blink-pairs"], name = "blink.pairs", event = "VeryLazy", opts = {mappings = {enabled = true, cmdline = true}, highlights = {enabled = true, cmdline = true, matchparen = {enabled = true, cmdline = true, include_surrounding = false}}}}}
