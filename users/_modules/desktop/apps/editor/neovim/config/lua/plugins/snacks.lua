-- [nfnl] fnl/plugins/snacks.fnl
local function k(rhs)
	return { rhs, mode = { "i", "n" } }
end
local keyset = {
	["/"] = "toggle_focus",
	["<A-j>"] = k("list_down"),
	["<A-k>"] = k("list_up"),
	["<CR>"] = k("confirm"),
	["<A-S-k>"] = k("toggle_hidden"),
	["<A-S-l>"] = k("toggle_ignored"),
	["<C-h>"] = k("history_back"),
	["<C-l>"] = k("history_forward"),
	["<A-w>"] = k("cycle_win"),
	["<A-a>"] = k("select_all"),
	["<c-w>G"] = k("list_bottom"),
	["<c-w>gg"] = k("list_top"),
	["<c-w>h"] = k("layout_left"),
	["<c-w>j"] = k("layout_bottom"),
	["<c-w>k"] = k("layout_top"),
	["<c-w>l"] = k("layout_right"),
}
local function _1_(_)
	return (vim.fn.getcmdpos() > 0)
end
local _2_
do
	local filter
	local function _3_(x, _)
		local _5_
		do
			local t_4_ = x
			if nil ~= t_4_ then
				t_4_ = t_4_.file
			else
			end
			_5_ = t_4_
		end
		return not vim.endswith((_5_ or ""), ".lua")
	end
	filter = { filter = _3_ }
	local exc = { hidden = true, include = { ".env" }, exclude = { "*.lua" }, filter = filter }
	_2_ = { files = exc, grep = exc, explorer = exc, recent = { filter = filter } }
end
return {
	"folke/snacks.nvim",
	opts = {
		bigfile = { enabled = true },
		quickfile = { enabled = true },
		notify = { enabled = true },
		notifier = {
			enabled = true,
			width = { min = 50, max = 0.4 },
			height = { min = 1, max = 0.6 },
			margin = { top = 2, right = 1, bottom = 0 },
			padding = true,
			gap = 0,
			sort = { "level", "added" },
			level = vim.log.levels.TRACE,
			icons = {
				error = "\239\129\151 ",
				warn = "\239\129\177 ",
				info = "\239\129\154 ",
				debug = "\239\134\136 ",
				trace = "\238\182\166 ",
			},
			keep = _1_,
			style = "minimal",
			top_down = true,
			date_format = "%R",
			more_format = " \226\134\147 %d lines ",
			refresh = 50,
		},
		terminal = {},
		picker = {
			prompt = "> ",
			show_delay = 1000,
			layout = { preset = "vscode", layout = { width = 0.7, row = 10, border = "none" } },
			sources = _2_,
			matcher = { fuzzy = true, smartcase = true, cwd_bonus = true, frecency = true, history_bonus = true },
			ui_select = "true",
			win = { input = { keys = keyset }, list = { keys = keyset }, preview = { keys = keyset } },
			previewers = {
				diff = {
					style = "fancy",
					cmd = { "delta" },
					wo = { breakindent = true, wrap = true, linebreak = true, showbreak = "" },
				},
			},
		},
		dashboard = {
			preset = { header = _G.header },
			sections = { { section = "header" }, { section = "keys", gap = 1, padding = 1 }, { section = "startup" } },
		},
		styles = {
			input = { border = false },
			scratch = { border = false },
			split = { position = "bottom", height = 25, border = false },
			float = { border = true, width = 0.99, height = 0.99 },
		},
		input = { enabled = true },
		image = { enabled = true },
	},
}
