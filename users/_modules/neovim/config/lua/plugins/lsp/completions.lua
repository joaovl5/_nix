-- [nfnl] fnl/plugins/lsp/completions.fnl
local n = require("lib/nvim")
local function _1_()
  vim.api.nvim_set_keymap("i", "<Esc>", "pumvisible() ? \"\\<C-e><Esc>\" : \"\\<Esc>\"", {expr = true, silent = true})
  vim.api.nvim_set_keymap("i", "<C-c>", "pumvisible() ? \"\\<C-e><C-c>\" : \"\\<C-c>\"", {expr = true, silent = true})
  vim.api.nvim_set_keymap("i", "<BS>", "pumvisible() ? \"\\<C-e><BS>\" : \"\\<BS>\"", {expr = true, silent = true})
  vim.api.nvim_set_keymap("i", "<Tab>", "pumvisible() ? (complete_info().selected == -1 ? \"\\<C-n>\" : \"\\<C-y>\") : \"\\<Tab>\"", {expr = true, silent = true})
  vim.api.nvim_set_keymap("i", "<A-j>", "pumvisible() ? \"\\<C-n>\" : \"\\<A-j>\"", {expr = true, silent = true})
  vim.api.nvim_set_keymap("i", "<A-k>", "pumvisible() ? \"\\<C-p>\" : \"\\<A-k>\"", {expr = true, silent = true})
  vim.g.coq_settings = {auto_start = "shut-up", ["keymap.bigger_preview"] = nil, ["keymap.jump_to_mark"] = nil, ["keymap.pre_select"] = true, ["completion.always"] = true, ["display.preview.border"] = "solid", ["keymap.recommended"] = false}
  return nil
end
return {{"ms-jpq/coq_nvim", branch = "coq", build = "COQdeps", init = _1_, lazy = false}}
