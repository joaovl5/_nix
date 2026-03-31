-- [nfnl] fnl/plugins/lsp/languages/typescript.fnl
return {
	"pmizio/typescript-tools.nvim",
	dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
	ft = { "typescriptreact", "typescript" },
	opts = { settings = { tsserver_path = _G.tsserver_path } },
}
