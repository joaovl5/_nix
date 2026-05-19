(local M {})

(set M.v/uv (or vim.uv vim.loop))
(fn M.v/$ [...]
  (vim.cmd ...))

(fn M.v/n [...]
  (vim.notify ...))

(fn M.v/contains? [xs x]
  (vim.tbl_contains xs x))

(fn M.v/echo [chunks history? opts]
  (vim.api.nvim_echo chunks history? (or opts {})))

(fn M.v/env [key]
  (. vim.env key))

(fn M.v/cwd [...]
  (vim.fn.getcwd ...))

(fn M.v/input [...]
  (vim.ui.input ...))

(fn M.v/extend [xs ys]
  (vim.list_extend xs ys))

(fn M.v/fs-stat [path]
  (M.v/uv.fs_stat path))

(fn M.v/later [callback]
  (vim.schedule callback))

(fn M.v/getchar []
  (vim.fn.getchar))

(fn M.v/has? [feature]
  (= (vim.fn.has feature) 1))

(fn M.v/rtp-prepend [path]
  (vim.opt.rtp:prepend path))

(fn M.v/stdpath [path]
  (vim.fn.stdpath path))

(fn M.v/sys [cmd]
  (vim.fn.system cmd))

(fn M.v/autocmd [events opts]
  "Create autocommand"
  (vim.api.nvim_create_autocmd events opts))

(fn M.v/map [mode lhs rhs opts]
  "Sets a global mapping for the given mode.
  Ex: `(keymap [:n :i] ...)`"
  (vim.keymap.set mode lhs rhs (or opts {})))

; vim.api.nvim_buf_create_user_command
(fn M.v/usercmd [bufnr name opts handle]
  "Create a buffer-bound command
  Ex: `(usercmd 0 :MyCmd {:desc :MyCmd} #(do-thing))`"
  (vim.api.nvim_buf_create_user_command bufnr name handle opts))

M
