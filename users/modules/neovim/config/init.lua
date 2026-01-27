-- define leader key first to avoid conflicts
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.loader.enable()

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

_G.Config = {}

local plugins = { { "Olical/nfnl", lazy = false, priority = 1000 } }
local fnl_definition_paths = (vim.fn.stdpath("config") .. "/fnl/plugins")
if vim.loop.fs_stat(fnl_definition_paths) then
	for file in vim.fs.dir(fnl_definition_paths, { depth = 3 }) do
		if (file ~= "index.fnl") and file:match("^(.*)%.fnl$") then
			module = require(("plugins." .. file:match("^(.*)%.fnl$")))
			if (module == nil) or (type(module) == "boolean") then
				print(vim.inspect(file))
			end
			table.insert(plugins, module)
		else
		end
	end
else
end
require("lazy").setup(plugins, { ui = { border = "rounded" } })

require("options")
