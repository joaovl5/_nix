-- [nfnl] fnl/plugins/ui/statusline.fnl
local _local_1_ = require("lib/nvim")
local v_2f_24 = _local_1_["v/$"]
local function _2_()
  local name_1_auto = require("lualine")
  local fun_2_auto = name_1_auto.setup
  return fun_2_auto({})
end
local function _3_()
  local function _4_(input)
    if (nil ~= input) then
      return v_2f_24(("Tabby rename_tab " .. input))
    else
      return nil
    end
  end
  return vim.ui.input({prompt = "Enter name for tab: "}, _4_)
end
local function _6_(tabid)
  return tabid()
end
return {{"nvim-lualine/lualine.nvim", config = _2_, event = "VeryLazy"}, {"nanozuki/tabby.nvim", event = "VeryLazy", keys = {{"<leader>qr", _3_, desc = "Rename"}, {"<leader>qw", "<cmd>Tabby pick_window<cr>", desc = "Pick window"}, {"<leader>qq", "<cmd>Tabby jump_to_tab<cr>", desc = "Jump mode"}}, opts = {preset = "tab_only", option = {theme = {fill = "TabLineFill", head = "TabLine", current_tab = "TabLineSel", tab = "TabLine", win = "TabLine", tail = "TabLine"}, nerdfont = true, lualine_theme = nil, tab_name = {tab_fallback = _6_}, buf_name = {mode = "shorten"}}}}}
