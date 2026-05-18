-- [nfnl] fnl/plugins/remote.fnl
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_21_auto = {}
local function _3_()
  do
    local name_1_auto = require("remote-sshfs")
    local fun_2_auto = name_1_auto.setup
    fun_2_auto({})
  end
  local name_1_auto = require("telescope")
  local fun_2_auto = name_1_auto.load_extension
  return fun_2_auto("remote-sshfs")
end
for __22_auto, attrs_23_auto in ipairs({_1_.deps({"nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim"}), _1_.event("VeryLazy"), _1_.config(_3_)}) do
  for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
    spec_21_auto[key_24_auto] = value_25_auto
  end
end
spec_21_auto[1] = "nosduco/remote-sshfs.nvim"
return spec_21_auto
