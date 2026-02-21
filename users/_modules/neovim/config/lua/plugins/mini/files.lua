-- [nfnl] fnl/plugins/mini/files.fnl
local n = require("lib/nvim")
local function _1_()
	local function _2_(args)
		local win_id = args.data.win_id
		local config = vim.api.nvim_win_get_config(win_id)
		config.border = "solid"
		config.title_pos = "center"
		return vim.api.nvim_win_set_config(win_id, config)
	end
	return n.autocmd("User", { pattern = "MiniFilesWindowOpen", callback = _2_ })
end
return {
	"nvim-mini/mini.files",
	version = "*",
	opts = { windows = { preview = true, width_focus = 40, width_nofocus = 30, max_number = 3 } },
	mappings = _G.MiniFilesMappings,
	init = _1_,
}
