-- [nfnl] fnl/plugins/mini/files.fnl
local mappings = {close = "q", go_in = "l", go_in_plus = "L", go_out = "h", go_out_plus = "H", mark_goto = "'", mark_set = "m", reset = "<BS>", reveal_cwd = "@", show_help = "?", synchronize = "=", trim_left = "<", trim_right = ">"}
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_21_auto = {}
local function _3_()
  return MiniFiles.open()
end
local function _4_()
  return MiniFiles.open(vim.api.nvim_buf_get_name(0))
end
for __22_auto, attrs_23_auto in ipairs({_1_.version("*"), _1_.keys(_2_.bind(_2_.l("E"), _3_, _2_.desc("Explore root")), _2_.bind(_2_.l("e"), _4_, _2_.desc("Explore at file"))), _1_.opts({windows = {preview = true}, width_focus = 40, width_nofocus = 30, max_number = 3, mappings = mappings})}) do
  for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
    spec_21_auto[key_24_auto] = value_25_auto
  end
end
spec_21_auto[1] = "nvim-mini/mini.files"
return spec_21_auto
