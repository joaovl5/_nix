-- [nfnl] fnl/lib/nvim.fnl
local M = {}
M["v/uv"] = (vim.uv or vim.loop)
M["v/$"] = vim.cmd
M["v/contains?"] = function(xs, x)
  return vim.tbl_contains(xs, x)
end
M["v/echo"] = function(chunks, history_3f, opts)
  return vim.api.nvim_echo(chunks, history_3f, (opts or {}))
end
M["v/env"] = function(key)
  return vim.env[key]
end
M["v/cwd"] = function(...)
  return vim.fn.getcwd(...)
end
M["v/input"] = function(...)
  return vim.ui.input(...)
end
M["v/extend"] = function(xs, ys)
  return vim.list_extend(xs, ys)
end
M["v/fs-stat"] = function(path)
  return M["v/uv"].fs_stat(path)
end
M["v/later"] = function(callback)
  return vim.schedule(callback)
end
M["v/getchar"] = function()
  return vim.fn.getchar()
end
M["v/has?"] = function(feature)
  return (vim.fn.has(feature) == 1)
end
M["v/rtp-prepend"] = function(path)
  return vim.opt.rtp:prepend(path)
end
M["v/stdpath"] = function(path)
  return vim.fn.stdpath(path)
end
M["v/sys"] = function(cmd)
  return vim.fn.system(cmd)
end
M["v/autocmd"] = function(events, opts)
  return vim.api.nvim_create_autocmd(events, opts)
end
M["v/map"] = function(mode, lhs, rhs, opts)
  return vim.keymap.set(mode, lhs, rhs, (opts or {}))
end
M["v/usercmd"] = function(bufnr, name, opts, handle)
  return vim.api.nvim_buf_create_user_command(bufnr, name, handle, opts)
end
return M
