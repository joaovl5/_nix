-- [nfnl] fnl/plugins/telescope.fnl
local _local_1_ = require("lib/nvim")
local v_2f_24 = _local_1_["v/$"]
local zox_ev_action
local function _2_(sel)
  v_2f_24.cd(sel.path)
  return MiniFiles.open(sel.path)
end
zox_ev_action = _2_
local zox_ev_after_action
local function _3_(sel)
  return vim.notify(("Directory changed to `" .. sel.path .. "`"))
end
zox_ev_after_action = _3_
local zoxide_cfg = {prompt_title = "\226\136\159 Zoxide Pick \226\175\190", mappings = {default = {action = zox_ev_action, after_action = zox_ev_after_action}}}
return {"nvim-telescope/telescope.nvim", dependencies = {"nvim-lua/popup.nvim", "nvim-lua/plenary.nvim", "jvgrootveld/telescope-zoxide"}, event = "VeryLazy", opts = {zoxide = zoxide_cfg}}
