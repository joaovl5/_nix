-- [nfnl] fnl/plugins/lsp/coq.fnl
local function _1_()
  vim.g.coq_settings = {auto_start = true}
  return nil
end
return {{"ms-jpq/coq_nvim", branch = "coq", init = _1_, lazy = false}}
