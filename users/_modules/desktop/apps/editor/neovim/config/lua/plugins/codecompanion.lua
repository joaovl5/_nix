-- [nfnl] fnl/plugins/codecompanion.fnl
local function _1_()
	local base_model = "minimax/minimax-m2.5"
	local _2_
	do
		local adap_cfg = { adapter = "openrouter" }
		_2_ = {
			chat = { adapter = "openrouter", model = base_model, tools = { opts = { auto_submit_errors = true } } },
			inline = adap_cfg,
			cmd = adap_cfg,
			background = adap_cfg,
		}
	end
	local function _3_(data)
		return (data.cwd == vim.fn.getcwd())
	end
	local function _4_()
		local name_2_auto = require("codecompanion.adapters")
		local fun_3_auto = name_2_auto.extend
		return fun_3_auto("openai_compatible", {
			env = { api_key = "OPENROUTER_API_KEY", url = "https://openrouter.ai/api" },
			name = "openrouter",
			formatted_name = "Openrouter API",
		})
	end
	return {
		interactions = _2_,
		extensions = {
			history = {
				enabled = true,
				dir_to_save = (vim.fn.stdpath("data") .. "/codecompanion_chats.json"),
				opts = {
					expiration_days = 7,
					chat_filter = _3_,
					title_generation_opts = { adapter = "openrouter", model = base_model },
					summary = { generation_opts = { adapter = "openrouter", model = base_model } },
				},
			},
			spinner = {},
		},
		adapters = { http = { openrouter = _4_ } },
	}
end
return {
	"olimorris/codecompanion.nvim",
	version = "^18.0.0",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"ravitemer/codecompanion-history.nvim",
		"franco-ruggeri/codecompanion-spinner.nvim",
	},
	opts = _1_,
}
