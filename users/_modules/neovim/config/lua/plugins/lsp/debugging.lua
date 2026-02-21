-- [nfnl] fnl/plugins/lsp/debugging.fnl
local function _1_()
	local dap = require("dap")
	dap.adapters["pwa-node"] = {
		type = "server",
		host = "localhost",
		port = "${port}",
		executable = { command = "js-debug", args = { "${port}" } },
	}
	dap.configurations.typescript = {
		{ type = "pwa-node", request = "launch", name = "Launch File", program = "${file}", cwd = "${workspaceFolder}" },
	}
	dap.configurations.javascript = {
		{ type = "pwa-node", request = "launch", name = "Launch File", program = "${file}", cwd = "${workspaceFolder}" },
	}
	return nil
end
local function _2_()
	local name_2_auto = require("dap-python")
	local fun_3_auto = name_2_auto.setup
	return fun_3_auto("uv")
end
return {
	{
		"mfussenegger/nvim-dap",
		config = _1_,
		dependencies = { { "mfussenegger/nvim-dap-python", config = _2_ }, "rcarriga/cmp-dap" },
		opts = false,
	},
	{ "rcarriga/nvim-dap-ui", opts = {}, dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" } },
}
