(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)
(local nvim (require :lib/nvim))

(fn current-snacks-terminal []
  (let [list-terminals (?. Snacks :terminal :list)]
    (when list-terminals
      (let [bufnr (vim.api.nvim_get_current_buf)]
        (var current nil)
        (each [_ terminal (ipairs (list-terminals))]
          (when (and (not current) (= terminal.buf bufnr))
            (set current terminal)))
        current))))

(fn snacks_terminal_state [terminal]
  (when (and terminal terminal.buf (vim.api.nvim_buf_is_valid terminal.buf))
    (let [(ok state) (pcall vim.api.nvim_buf_get_var terminal.buf
                            :snacks_terminal)]
      (when ok state))))

(fn lazygit_terminal? [terminal]
  (let [state (snacks_terminal_state terminal)]
    (and state (or (= state.cmd :lazygit) (= state.id :lazygit)))))

(fn hide_terminal [terminal winnr]
  (when (and terminal (not= terminal.win winnr) (terminal:valid))
    (terminal:hide)))

(fn handle_should_block [argv]
  (vim.tbl_contains argv :-b))

(fn register_autocmd [bufnr]
  (let [callback (fn []
                   (vim.api.nvim_buf_delete bufnr))]
    (nvim.autocmd :BufWritePost
                  {:buffer bufnr
                   :once true
                   :callback (vim.schedule_wrap callback)})))

(fn flatten_setup []
  (var saved-terminal nil)

  (fn handle_pre_open [_]
    (set saved-terminal (current-snacks-terminal)))

  (fn handle_post_open [opts]
    (let [bufnr opts.bufnr
          winnr opts.winnr
          ft opts.filetype]
      (if opts.is_blocking
          (hide_terminal saved-terminal winnr)
          (do
            (when (lazygit_terminal? saved-terminal)
              (hide_terminal saved-terminal winnr))
            (when (and winnr (vim.api.nvim_win_is_valid winnr))
              (vim.api.nvim_set_current_win winnr))
            (set saved-terminal nil)))
      (when (or (= ft :gitcommit) (= ft :gitrebase))
        (register_autocmd bufnr))))

  (fn handle_block_end [_opts]
    (let [cb (fn []
               (when saved-terminal
                 (when (saved-terminal:buf_valid)
                   (saved-terminal:show))
                 (set saved-terminal nil)))]
      (vim.schedule cb)))

  {:nest_if_no_args true
   :nest_if_cmds true
   :window {:open :alternate :diff :split :focus :first}
   :hooks {:should_block handle_should_block
           :pre_open handle_pre_open
           :post_open handle_post_open
           :block_end handle_block_end}})

[(plugin :willothy/flatten.nvim
         {:opts flatten_setup :lazy false :priority 1001})]
