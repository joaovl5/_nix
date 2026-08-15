-- [nfnl] fnl/plugins/lsp/languages/svelte.fnl
vim.g.vim_svelte_plugin_load_full_syntax = 1
vim.g.vim_svelte_plugin_use_typescript = 1
vim.g.vim_svelte_plugin_use_less = 1
vim.g.vim_svelte_plugin_use_sass = 1
vim.g.vim_svelte_plugin_use_stylus = 1
vim.g.vim_svelte_plugin_use_foldexpr = 1
local function _3_(...)
  local _1_ = require("lib.plugins")
  local _2_ = require("lib.keys")
  local spec_24_auto = {}
  for __25_auto, attrs_26_auto in ipairs({}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "leafOfTree/vim-svelte-plugin"
  return spec_24_auto
end
return {_3_(...)}
