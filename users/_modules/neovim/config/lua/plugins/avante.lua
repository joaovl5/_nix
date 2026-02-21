-- [nfnl] fnl/plugins/avante.fnl
local img_clip = {
	"HakonHarnes/img-clip.nvim",
	event = "VeryLazy",
	opts = {
		default = { drag_and_drop = { insert_mode = true }, embed_image_as_base64 = false, prompt_for_file_name = false },
	},
	keys = { { "<leader>p", "<cmd>PasteImage<cr>", desc = "Paste image from clipboard" } },
}
local function _1_()
	return vim.cmd("make")
end
return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim", "echasnovski/mini.icons", img_clip },
	build = _1_,
	opts = {
		provider = "openai",
		providers = { openai = { model = "gpt-5.1" } },
		selector = { provider = "snacks", provider_opts = {} },
	},
	version = false,
}
