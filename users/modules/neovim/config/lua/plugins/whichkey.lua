-- [nfnl] fnl/plugins/whichkey.fnl
local function _1_()
  do
    local name_2_auto = require("which-key")
    local fun_3_auto = name_2_auto.setup
    fun_3_auto({preset = "helix"})
  end
  return require("./keymaps")
end
return {"folke/which-key.nvim", config = _1_, lazy = false}
