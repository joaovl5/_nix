-- [nfnl] fnl/plugins/neoconf.fnl
return {
	"folke/neoconf.nvim",
	event = "VeryLazy",
	opts = {
		local_settings = ".neoconf.json",
		global_settings = "neoconf.json",
		plugins = { lspconfig = { enabled = false }, jsonls = { enabled = false }, lua_ls = { enabled = false } },
		import = { coc = false, nlsp = false, vscode = false },
		live_reload = false,
	},
}
