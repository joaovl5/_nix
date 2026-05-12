-- [nfnl] fnl/plugins/lsp/languages/typescript.fnl
local n = require("lib/nvim")
local js_ts_filetypes =
	{ "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" }
local function _1_()
	local function _2_(ev)
		local function _3_()
			local name_2_auto = require("lazy")
			local fun_3_auto = name_2_auto.load
			return fun_3_auto({ plugins = { "typescript-tools.nvim" } })
		end
		return vim.api.nvim_buf_call(ev.buf, _3_)
	end
	return n.autocmd("FileType", { pattern = js_ts_filetypes, once = true, callback = _2_ })
end
return {
	"pmizio/typescript-tools.nvim",
	dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
	lazy = true,
	init = _1_,
	opts = {},
}
