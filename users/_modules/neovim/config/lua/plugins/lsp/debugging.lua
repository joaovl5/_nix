-- [nfnl] fnl/plugins/lsp/debugging.fnl
local function _1_()
  local name_2_auto = require("dap-python")
  local fun_3_auto = name_2_auto.setup
  return fun_3_auto("uv")
end
return {{"mfussenegger/nvim-dap", dependencies = {{"mfussenegger/nvim-dap-python", config = _1_}, "rcarriga/cmp-dap"}, opts = false}, {"rcarriga/nvim-dap-ui", opts = {}, dependencies = {"mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"}}}
