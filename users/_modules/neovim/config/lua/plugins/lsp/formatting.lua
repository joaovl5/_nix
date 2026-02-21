-- [nfnl] fnl/plugins/lsp/formatting.fnl
return {
	"stevearc/conform.nvim",
	opts = {
		formatters = {
			prettierd = { command = "prettierd" },
			fnlfmt = { command = "fnlfmt" },
			alejandra = { command = "alejandra" },
		},
		formatters_by_ft = {
			python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },
			typescript = { "prettierd" },
			javascript = { "prettierd" },
			typescriptreact = { "prettierd" },
			handlebars = { "prettierd" },
			lua = { "stylua" },
			fennel = { "fnlfmt" },
			nix = { "alejandra" },
			rust = { "rust_fmt" },
			markdown = { "prettierd" },
		},
		format_on_save = { timeout_ms = 3000, lsp_format = "fallback" },
	},
}
