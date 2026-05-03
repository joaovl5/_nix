-- [nfnl] fnl/plugins/lsp/languages/python.fnl
return {
	"linux-cultist/venv-selector.nvim",
	dependencies = { { "nvim-telescope/telescope.nvim", version = "*" } },
	ft = "python",
	keys = { { "<leader>cv", "<cmd>VenvSelect<cr>", desc = "Pick virtual env" } },
	opts = {},
}
