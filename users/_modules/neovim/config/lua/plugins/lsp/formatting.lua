-- [nfnl] fnl/plugins/lsp/formatting.fnl
local formatters = {
	prettierd = { command = "prettierd" },
	fnlfmt = { command = "fnlfmt" },
	alejandra = { command = "alejandra" },
	nix_fmt = { command = "nix", args = { "fmt" } },
}
local default_formatters_by_ft = {
	python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },
	typescript = { "prettierd" },
	javascript = { "prettierd" },
	typescriptreact = { "prettierd" },
	handlebars = { "prettierd" },
	lua = { "stylua" },
	fennel = { "fnlfmt" },
	nix = { "alejandra" },
	rust = { "rust_fmt" },
	toml = { "taplo" },
	markdown = { "prettierd" },
}
local function get_project_formatters_by_ft(bufnr)
	local ok, neoconf = pcall(require, "neoconf")
	if ok then
		return neoconf.get("formatter.filetypes", {}, { buffer = bufnr, ["local"] = true, global = false })
	else
		return {}
	end
end
local function resolve_formatters_for_ft(bufnr, filetype)
	local project_map = get_project_formatters_by_ft(bufnr)
	local override = project_map[filetype]
	if vim.islist(override) then
		return override
	else
		return default_formatters_by_ft[filetype]
	end
end
local formatters_by_ft
local function _3_(_241)
	return resolve_formatters_for_ft(_241, "python")
end
local function _4_(_241)
	return resolve_formatters_for_ft(_241, "typescript")
end
local function _5_(_241)
	return resolve_formatters_for_ft(_241, "javascript")
end
local function _6_(_241)
	return resolve_formatters_for_ft(_241, "typescriptreact")
end
local function _7_(_241)
	return resolve_formatters_for_ft(_241, "handlebars")
end
local function _8_(_241)
	return resolve_formatters_for_ft(_241, "lua")
end
local function _9_(_241)
	return resolve_formatters_for_ft(_241, "fennel")
end
local function _10_(_241)
	return resolve_formatters_for_ft(_241, "nix")
end
local function _11_(_241)
	return resolve_formatters_for_ft(_241, "rust")
end
local function _12_(_241)
	return resolve_formatters_for_ft(_241, "toml")
end
local function _13_(_241)
	return resolve_formatters_for_ft(_241, "markdown")
end
formatters_by_ft = {
	python = _3_,
	typescript = _4_,
	javascript = _5_,
	typescriptreact = _6_,
	handlebars = _7_,
	lua = _8_,
	fennel = _9_,
	nix = _10_,
	rust = _11_,
	toml = _12_,
	markdown = _13_,
}
return {
	"stevearc/conform.nvim",
	dependencies = { "folke/neoconf.nvim" },
	opts = {
		formatters = formatters,
		formatters_by_ft = formatters_by_ft,
		format_on_save = { timeout_ms = 3000, lsp_format = "fallback" },
	},
}
