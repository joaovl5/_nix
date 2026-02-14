-- [nfnl] fnl/plugins/whichkey.fnl
local function _1_()
  do
    local name_2_auto = require("which-key")
    local fun_3_auto = name_2_auto.setup
    fun_3_auto({preset = "modern", plugins = {spelling = {enabled = false}}, win = {padding = {1, 1}, border = "none", width = {max = 80}, title = false}, layout = {spacing = 5, width = {min = 30}}, delay = 50})
  end
  return require("./keymaps")
end
return {"folke/which-key.nvim", config = _1_, lazy = false}
