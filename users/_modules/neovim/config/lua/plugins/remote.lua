-- [nfnl] fnl/plugins/remote.fnl
local function _1_()
	do
		local name_2_auto = require("remote-sshfs")
		local fun_3_auto = name_2_auto.setup
		fun_3_auto({})
	end
	local name_2_auto = require("telescope")
	local fun_3_auto = name_2_auto.load_extension
	return fun_3_auto("remote-sshfs")
end
return {
	"nosduco/remote-sshfs.nvim",
	depends = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
	event = "VeryLazy",
	config = _1_,
}
