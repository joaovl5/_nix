-- [nfnl] fnl/plugins/editor/motions.fnl
local function _1_()
  local leap = require("leap")
  local leap_user = require("leap.user")
  local function _2_(ch0, ch1, ch2)
    return not (ch1:match("%s") or (ch0:match("%a") and ch1:match("%a") and ch2:match("%a")))
  end
  leap.opts.preview = _2_
  leap.opts.equivalence_classes = {" \t\r\n", "([{", ")]}", "'\"`"}
  return leap_user.set_repeat_keys("<enter>", "<backspace>")
end
return {{"mluders/comfy-line-numbers.nvim", opts = true}, {"https://codeberg.org/andyg/leap.nvim", dependencies = {"tpope/vim-repeat"}, config = _1_}, {"chrisgrieser/nvim-spider", opts = true}, {"sontungexpt/bim.nvim", opts = true}}
