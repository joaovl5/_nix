-- [nfnl] fnl/plugins/editor/motions.fnl
return {
	{ "mluders/comfy-line-numbers.nvim", opts = true, event = "BufEnter" },
	{
		"folke/flash.nvim",
		event = "BufEnter",
		opts = {
			labels = "fhdjskalgrueiwoqptvnmb",
			search = { forward = true, wrap = true, mode = "exact", multi_window = false },
			jump = { nohlsearch = true, autojump = true },
			label = { distance = true, rainbow = { enabled = true, shade = 5 }, uppercase = false },
			highlight = { backdrop = true },
			modes = {
				treesitter = { labels = "fhdjskalgrueiwoqptvnmb", highlight = { backdrop = true, matches = false } },
			},
		},
	},
	{ "chrisgrieser/nvim-spider", opts = true },
	{ "aaronik/treewalker.nvim", opts = {}, cmd = "Treewalker" },
	{ "sontungexpt/bim.nvim", opts = true, event = "InsertEnter" },
}
