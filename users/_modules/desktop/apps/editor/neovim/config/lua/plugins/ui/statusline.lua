-- [nfnl] fnl/plugins/ui/statusline.fnl
local function _1_()
	local name_2_auto = require("lualine")
	local fun_3_auto = name_2_auto.setup
	return fun_3_auto({})
end
local function _2_()
	local function _3_(input)
		if nil ~= input then
			return vim.cmd(("Tabby rename_tab " .. input))
		else
			return nil
		end
	end
	return vim.ui.input({ prompt = "Enter name for tab: " }, _3_)
end
local function _5_(tabid)
	return tabid()
end
return {
	{ "nvim-lualine/lualine.nvim", config = _1_, event = "VeryLazy" },
	{
		"nanozuki/tabby.nvim",
		event = "VeryLazy",
		keys = {
			{ "<leader>qr", _2_, desc = "Rename" },
			{ "<leader>qw", "<cmd>Tabby pick_window<cr>", desc = "Pick window" },
			{ "<leader>qq", "<cmd>Tabby jump_to_tab<cr>", desc = "Jump mode" },
		},
		opts = {
			preset = "tab_only",
			option = {
				theme = {
					fill = "TabLineFill",
					head = "TabLine",
					current_tab = "TabLineSel",
					tab = "TabLine",
					win = "TabLine",
					tail = "TabLine",
				},
				nerdfont = true,
				lualine_theme = nil,
				tab_name = { tab_fallback = _5_ },
				buf_name = { mode = "shorten" },
			},
		},
	},
}
