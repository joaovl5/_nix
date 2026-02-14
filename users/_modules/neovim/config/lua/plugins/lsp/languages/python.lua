-- [nfnl] fnl/plugins/lsp/languages/python.fnl
local n = require("lib/nvim")
local function _1_()
  do
    local name_2_auto = require("swenv")
    local fun_3_auto = name_2_auto.setup
    local function _2_()
      return vim.cmd("LspRestart")
    end
    fun_3_auto({post_set_venv = _2_})
  end
  local function _3_()
    local name_2_auto = require("swenv.api")
    local fun_3_auto = name_2_auto.auto_venv
    return fun_3_auto()
  end
  return n.autocmd("FileType", {pattern = {"python"}, callback = _3_})
end
return {"AckslD/swenv.nvim", event = "VeryLazy", config = _1_}
