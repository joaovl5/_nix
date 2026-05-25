-- [nfnl] fnl/plugins/lsp/repl.fnl
local function init_conjure()
  vim.g["conjure#mapping#prefix"] = ","
  return nil
end
init_conjure()
return {}
