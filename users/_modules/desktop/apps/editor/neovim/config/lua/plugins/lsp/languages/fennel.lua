-- [nfnl] fnl/plugins/lsp/languages/fennel.fnl
local function build_parinfer(params)
	vim.notify("Building Parinfer", vim.log.levels.INFO)
	local res = vim.system({ "cargo", "build", "--release" }, { cwd = params.path }):wait()
	if 0 == res.code then
		return vim.notify("Building Parinfer done", vim.log.levels.INFO)
	elseif res.code() then
		return vim.notify(
			("Building Parinfer failed\n\nSTDOUT: " .. res.stdout .. "\n\nSTDERR: " .. res.stderr),
			vim.log.levels.ERROR
		)
	else
		return nil
	end
end
return { { "eraserhd/parinfer-rust", build = build_parinfer, ft = { "fennel" } } }
