-- [nfnl] fnl/plugins/mini/misc.fnl
local function _1_()
  do
    local name_1_auto = require("mini.misc")
    local fun_2_auto = name_1_auto.setup
    fun_2_auto({})
  end
  MiniMisc.setup_restore_cursor()
  return MiniMisc.setup_termbg_sync()
end
return { "nvim-mini/mini.misc", version = "*", config = _1_ }
