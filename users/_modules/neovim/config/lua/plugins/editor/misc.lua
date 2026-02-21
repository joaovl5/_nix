-- [nfnl] fnl/plugins/editor/misc.fnl
return {
	{
		"folke/zen-mode.nvim",
		dependencies = { "folke/twilight.nvim" },
		opts = { window = { backdrop = 1, width = 110, height = 1 } },
		plugins = {
			options = { enabled = true, ruler = true, laststatus = 0, showcmd = false },
			twilight = { enabled = true },
			gitsigns = { enabled = true },
			tmux = { enabled = true },
		},
	},
}
