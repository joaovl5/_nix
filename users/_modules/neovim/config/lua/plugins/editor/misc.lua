-- [nfnl] fnl/plugins/editor/misc.fnl
return {
	{
		"folke/zen-mode.nvim",
		opts = { window = { backdrop = 1, width = 110, height = 1 } },
		plugins = {
			options = { enabled = true, ruler = true, laststatus = 0, showcmd = false },
			twilight = { enabled = false },
			gitsigns = { enabled = true },
			tmux = { enabled = true },
		},
	},
}
