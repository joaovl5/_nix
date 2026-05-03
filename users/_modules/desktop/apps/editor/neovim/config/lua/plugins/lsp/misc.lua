-- [nfnl] fnl/plugins/lsp/misc.fnl
return {
	{
		dir = _G.plugin_dirs["blink-pairs"],
		name = "blink.pairs",
		event = "VeryLazy",
		opts = {
			mappings = { enabled = true, cmdline = true },
			highlights = {
				enabled = true,
				cmdline = true,
				matchparen = { enabled = true, cmdline = true, include_surrounding = false },
			},
		},
	},
	{ "folke/ts-comments.nvim", opts = {}, event = "VeryLazy" },
}
