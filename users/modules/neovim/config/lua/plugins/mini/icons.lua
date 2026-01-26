-- [nfnl] fnl/plugins/mini/icons.fnl
local function _1_()
  local icons = require("mini.icons")
  icons.setup({})
  MiniIcons.mock_nvim_web_devicons()
  return MiniIcons.tweak_lsp_kind()
end
return {"nvim-mini/mini.icons", version = "*", event = "VeryLazy", config = _1_}
