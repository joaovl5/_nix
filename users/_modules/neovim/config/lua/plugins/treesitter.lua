-- [nfnl] fnl/plugins/treesitter.fnl
local n = require("lib/nvim")
local languages =
	{ "lua", "vimdoc", "markdown", "python", "javascript", "jsx", "typescript", "tsx", "fennel", "html", "css", "scss" }
do
	local ts = require("nvim-treesitter.config")
	ts.setup({ auto_install = false })
end
do
	local filetypes
	do
		local res = {}
		for _, lang in ipairs(languages) do
			res = vim.list_extend(res, vim.treesitter.language.get_filetypes(lang))
		end
		filetypes = res
	end
	local function _1_(ev)
		return vim.treesitter.start(ev.buf)
	end
	n.autocmd("FileType", { pattern = filetypes, callback = _1_ })
end
return {}
