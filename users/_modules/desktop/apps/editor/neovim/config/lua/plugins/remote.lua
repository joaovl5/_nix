-- [nfnl] fnl/plugins/remote.fnl
local function _1_()
  do
    local name_1_auto = require("remote-sshfs")
    local fun_2_auto = name_1_auto.setup
    fun_2_auto({})
  end
  local name_1_auto = require("telescope")
  local fun_2_auto = name_1_auto.load_extension
  return fun_2_auto("remote-sshfs")
end
return {"nosduco/remote-sshfs.nvim", depends = {"nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim"}, event = "VeryLazy", config = _1_}
