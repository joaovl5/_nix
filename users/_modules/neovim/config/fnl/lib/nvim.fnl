(fn autocmd [events opts]
  "Create autocommand"
  (vim.api.nvim_create_autocmd events opts))

(fn map [mode lhs rhs opts]
  "Sets a global mapping for the given mode.
  Ex: `(keymap [:n :i] ...)`"
  (vim.keymap.set mode lhs rhs (or opts {})))

; vim.api.nvim_buf_create_user_command
(fn usercmd [bufnr name opts handle]
  "Create a buffer-bound command
  Ex: `(usercmd 0 :MyCmd {:desc :MyCmd} #(do-thing))`"
  (vim.api.nvim_buf_create_user_command bufnr name handle opts))

{: autocmd : map : usercmd}
