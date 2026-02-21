-- [nfnl] fnl/plugins/themery.fnl
local function _1_()
	local theme_names
	do
		local all_names = {}
		for _, theme in ipairs((_G.Config.themes or {})) do
			all_names = vim.list_extend(all_names, theme.names)
		end
		theme_names = all_names
	end
	local name_2_auto = require("themery")
	local fun_3_auto = name_2_auto.setup
	return fun_3_auto({ themes = theme_names, livePreview = true })
end
return { "zaldih/themery.nvim", config = _1_, lazy = false }
