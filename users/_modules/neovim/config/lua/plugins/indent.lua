-- [nfnl] fnl/plugins/indent.fnl
local function _1_()
	local ibl = require("ibl")
	local hk = require("ibl.hooks")
	local hl_setup = hk.type.HIGHLIGHT_SETUP
	local set_hl = vim.api.nvim_set_hl
	local bg_hl = "DimDim"
	local hl = "RainbowViolet"
	local function _2_()
		set_hl(0, "RainbowViolet", { fg = "#AB94FC" })
		return set_hl(0, "DimDim", { fg = "#303030" })
	end
	hk.register(hl_setup, _2_)
	return ibl.setup({
		indent = { highlight = bg_hl, char = "\226\139\174" },
		scope = { highlight = hl, char = "\226\139\174", show_exact_scope = true },
	})
end
return { "lukas-reineke/indent-blankline.nvim", main = "ibl", event = "BufEnter", config = _1_ }
