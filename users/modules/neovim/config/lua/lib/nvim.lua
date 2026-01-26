-- [nfnl] fnl/lib/nvim.fnl
local function autocmd(events, opts)
  return vim.api.nvim_create_autocmd(events, opts)
end
local function map(mode, lhs, rhs, opts)
  return vim.keymap.set(mode, lhs, rhs, (opts or {}))
end
local function usercmd(bufnr, name, opts, handle)
  return vim.api.nvim_buf_create_user_command(bufnr, name, handle, opts)
end
return {autocmd = autocmd, map = map, usercmd = usercmd}
