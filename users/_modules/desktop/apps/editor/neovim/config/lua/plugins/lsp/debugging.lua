-- [nfnl] fnl/plugins/lsp/debugging.fnl
local _local_1_ = require("lib/nvim")
local v_2finput = _local_1_["v/input"]
local _4_
do
  local _2_ = require("lib.plugins")
  local _3_ = require("lib.keys")
  local spec_24_auto = {}
  local function _5_()
    local dap = require("dap")
    dap.adapters["pwa-node"] = {type = "server", host = "localhost", port = "${port}", executable = {command = "js-debug", args = {"${port}"}}}
    dap.configurations.typescript = {{type = "pwa-node", request = "launch", name = "Launch File", program = "${file}", cwd = "${workspaceFolder}"}}
    dap.configurations.javascript = {{type = "pwa-node", request = "launch", name = "Launch File", program = "${file}", cwd = "${workspaceFolder}"}}
    return nil
  end
  local function _8_(...)
    local _6_ = require("lib.plugins")
    local _7_ = require("lib.keys")
    local spec_24_auto0 = {}
    local function _9_()
      local name_1_auto = require("dap-python")
      local fun_2_auto = name_1_auto.setup
      return fun_2_auto("uv")
    end
    for __25_auto, attrs_26_auto in ipairs({_6_.config(_9_)}) do
      for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
        spec_24_auto0[key_27_auto] = value_28_auto
      end
    end
    spec_24_auto0[1] = "mfussenegger/nvim-dap-python"
    return spec_24_auto0
  end
  for __25_auto, attrs_26_auto in ipairs({_2_.opts(false), _2_.keys(_3_.group("debug", _3_.bind("s", {group = "Session"}), _3_.bind("sn", _3_.cmd("DapNew"), _3_.desc("New Session")), _3_.bind("sc", _3_.cmd("DapContinue"), _3_.desc("Continue Session")), _3_.bind("b", _3_.cmd("DapToggleBreakpoint"), _3_.desc("Breakpoint")), _3_.bind("j", _3_.cmd("DapStepOver"), _3_.desc("Step over")), _3_.bind("l", _3_.cmd("DapStepInto"), _3_.desc("Step into")), _3_.bind("r", _3_.cmd("DapToggleRepl"), _3_.desc("Repl")))), _2_.config(_5_), _2_.deps({"rcarriga/cmp-dap", _8_(...)})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "mfussenegger/nvim-dap"
  _4_ = spec_24_auto
end
local function _12_(...)
  local _10_ = require("lib.plugins")
  local _11_ = require("lib.keys")
  local spec_24_auto = {}
  local function _13_()
    local name_1_auto = require("dapui")
    local fun_2_auto = name_1_auto.eval
    return fun_2_auto()
  end
  local function _14_()
    local function _15_(_2410)
      local name_1_auto = require("dapui")
      local fun_2_auto = name_1_auto.eval
      return fun_2_auto(_2410)
    end
    return v_2finput({prompt = "Expression to evaluate"}, _15_)
  end
  for __25_auto, attrs_26_auto in ipairs({_10_.keys(_11_.group("debug", _11_.bind("e", _13_, _11_.desc("Eval under cursor")), _11_.bind("x", _14_, _11_.desc("Eval expression")))), _10_.opts({}), _10_.deps({"mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "rcarriga/nvim-dap-ui"
  return spec_24_auto
end
return {_4_, _12_(...)}
