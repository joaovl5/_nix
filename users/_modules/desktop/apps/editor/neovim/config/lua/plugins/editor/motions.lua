-- [nfnl] fnl/plugins/editor/motions.fnl
local _1_
do
  local keys = "fhdjskalgrueiwoqptvnmb"
  _1_ = {
    labels = keys,
    search = {
      forward = true,
      wrap = true,
      mode = "fuzzy",
      multi_window = false,
    },
    jump = { nohlsearch = true, autojump = true },
    label = { distance = true, uppercase = false },
    highlight = { backdrop = true },
    modes = {
      treesitter = {
        labels = keys,
        highlight = { backdrop = true, matches = false },
      },
    },
  }
end
return {
  { "mluders/comfy-line-numbers.nvim", opts = true, event = "BufEnter" },
  { "folke/flash.nvim", event = "BufEnter", opts = _1_ },
  { "chrisgrieser/nvim-spider", opts = true },
  { "aaronik/treewalker.nvim", opts = {}, cmd = "Treewalker" },
}
