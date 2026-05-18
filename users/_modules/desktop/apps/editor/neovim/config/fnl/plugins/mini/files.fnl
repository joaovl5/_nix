(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)

(local mappings {:close :q
                 :go_in :l
                 :go_in_plus :L
                 :go_out :h
                 :go_out_plus :H
                 :mark_goto "'"
                 :mark_set :m
                 :reset :<BS>
                 :reveal_cwd "@"
                 :show_help "?"
                 :synchronize "="
                 :trim_left "<"
                 :trim_right ">"})

(p! :nvim-mini/mini.files
    (version "*")
    (keys
      (bind (l :E)
            #(MiniFiles.open)
            (desc "Explore root"))
      (bind (l :e)
            #(MiniFiles.open (vim.api.nvim_buf_get_name 0))
            (desc "Explore at file")))
    (opts {:windows {:preview true}
           :width_focus 40
           :width_nofocus 30
           :max_number 3
           : mappings}))
