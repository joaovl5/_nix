-- [nfnl] fnl/plugins/lsp/languages/fennel.fnl
local function build_parinfer(params)
  vim.notify("Building Parinfer", vim.log.levels.INFO)
  local res = vim.system({"cargo", "build", "--release"}, {cwd = params.path}):wait()
  if (0 == res.code) then
    return vim.notify("Building Parinfer done", vim.log.levels.INFO)
  else
    return vim.notify("Building Parinfer failed", vim.log.levels.ERROR)
  end
end
return {{"bakpakin/fennel.vim", ft = "fennel"}, {"eraserhd/parinfer-rust", build = build_parinfer}}
