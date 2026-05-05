-- [nfnl] fnl/plugins/editor/git.fnl
return {
	{
		"lewis6991/gitsigns.nvim",
		opts = {},
		event = "VeryLazy",
		keys = {
			{ "<leader>gb", "<cmd>Gitsigns blame_line<cr>", desc = "Blame (line)" },
			{ "<leader>gB", "<cmd>Gitsigns blame<cr>", desc = "Blame (all)" },
		},
	},
}
