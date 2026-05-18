(import-macros {: p!} :./lib/init-macros)

(fn pick [name ...]
  ((. Snacks.picker name) ...))

(fn toggle_term [_ cmd]
  "Toggles (or creates) a terminal instance by its id"
  (Snacks.terminal.toggle cmd {}))

(p! :folke/snacks.nvim
    (lazy false)
    (keys
      (bind (a "/") #(Snacks.terminal.toggle) (desc "Terminal") (m :n :t))
      (bind (l "<leader>") #(pick :files) (desc "Fuzzy Files"))
      (bind (l ".")
            #(let [buf_name (vim.api.nvim_buf_get_name 0)
                   buf_dir (vim.fs.dirname buf_name)]
               (pick :files {:cwd buf_dir}))
            (desc "Fuzzy Files (buffer)"))
      (group
        :git
        (bind :g #(toggle_term :lazygit :lazygit) (desc "Lazygit")))
      (group
        :fuzzy
        (bind ":" #(pick :command_history) (desc "':' history"))
        (bind :b #(pick :buffers) (desc "Buffers"))
        (bind :r #(pick :recent) (desc "Recent"))
        (bind :p #(pick :projects) (desc "Projects"))
        (bind :d #(pick :diagnostics) (desc "Diagnostics"))
        (bind :h #(pick :help) (desc "Help Tags"))
        (bind :m #(pick :man) (desc "Man pages"))
        (bind :H #(pick :highlights) (desc "Highlights"))
        (bind :s #(pick :lsp_workspace_symbols) (desc "Symbols"))
        (bind :S #(pick :lsp_symbols) (desc "Symbols (buffer)")))
      (group
        :buffer
        (bind :b #(Snacks.scratch) (desc "Scratch"))
        (bind :B #(Snacks.scratch.select) (desc "Scratch (pick)"))))
    (opts {; optimize big file views
           :bigfile {:enabled true}
           ; loads files faster
           :quickfile {:enabled true}
           ; notifications
           :notify {:enabled true}
           :notifier (require :plugins.snacks._notifier)
           ; terminal
           :terminal {}
           ; picker
           :picker (require :plugins.snacks._picker)
           ; ui-related
           :dashboard (require :plugins.snacks._dashboard)
           :styles (require :plugins.snacks._styles)
           :input {:enabled true}
           :image {:enabled true}}))
