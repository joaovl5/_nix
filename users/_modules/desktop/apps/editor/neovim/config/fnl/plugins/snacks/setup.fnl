(import-macros {: p!} :./lib/init-macros)

(fn pick [name ...]
  ((. Snacks.picker name) ...))

(fn toggle_term [_ cmd]
  "Toggles (or creates) a terminal instance by its id"
  (Snacks.terminal.toggle cmd {}))

(local default-terminal-left-min-columns 150)
(local default-terminal-left-width 0.25)

(fn default-terminal-position []
  (if (< vim.o.columns default-terminal-left-min-columns)
      :bottom
      :left))

(fn default-terminal-win-opts []
  (let [position (default-terminal-position)]
    (vim.tbl_extend :force
                    {:position position}
                    (if (= position :left)
                        {:width default-terminal-left-width}
                        {}))))

(fn default-terminal-opts []
  {:win (default-terminal-win-opts)})

(fn apply-default-terminal-position [terminal]
  (let [position (default-terminal-position)
        vertical? (= position :left)]
    (set terminal.opts.position position)
    (when vertical?
      (set terminal.opts.width default-terminal-left-width))
    (set terminal.opts.wo (or terminal.opts.wo {}))
    (set terminal.opts.wo.winfixheight (not vertical?))
    (set terminal.opts.wo.winfixwidth vertical?)))

(fn toggle-default-terminal []
  "Toggle the default terminal with size-aware split placement."
  (let [terminal (Snacks.terminal.get nil {:create false})]
    (if terminal
        (do
          (when (not (terminal:valid))
            (apply-default-terminal-position terminal))
          (terminal:toggle))
        (Snacks.terminal.toggle nil (default-terminal-opts)))))

(local tab-terminal-count 9001)
(var tab-terminal-previous-tabpage nil)

(fn tab-terminal-opts [?extra]
  (vim.tbl_deep_extend :force
                       {:count tab-terminal-count
                        :win {:position :current}}
                       (or ?extra {})))

(fn valid-tabpage? [tabpage]
  (and tabpage (vim.api.nvim_tabpage_is_valid tabpage)))

(fn focus-previous-tab []
  (if (valid-tabpage? tab-terminal-previous-tabpage)
      (vim.api.nvim_set_current_tabpage tab-terminal-previous-tabpage)
      (vim.cmd.tabprevious))
  (set tab-terminal-previous-tabpage nil))

(fn focus-terminal-tab [terminal]
  (let [terminal-tabpage (vim.api.nvim_win_get_tabpage terminal.win)
        current-tabpage (vim.api.nvim_get_current_tabpage)]
    (if (= current-tabpage terminal-tabpage)
        (focus-previous-tab)
        (do
          (set tab-terminal-previous-tabpage current-tabpage)
          (vim.api.nvim_set_current_tabpage terminal-tabpage)
          (terminal:focus)
          (vim.cmd.startinsert)))))

(fn focus-or-open-tab-term []
  "Focus the tab terminal, create it, or return to the previous tab."
  (let [terminal
        (Snacks.terminal.get
          nil
          (tab-terminal-opts {:create false}))]
    (if (and terminal (terminal:valid))
        (focus-terminal-tab terminal)
        (do
          (set tab-terminal-previous-tabpage
               (vim.api.nvim_get_current_tabpage))
          (vim.cmd.tabnew)
          (let [new-terminal
                (if terminal
                    (terminal:show)
                    (Snacks.terminal.open nil (tab-terminal-opts)))]
            (new-terminal:focus))))))

(p! :folke/snacks.nvim
    (lazy false)
    (keys
      (bind (a "/")
            #(toggle-default-terminal)
            (desc "Terminal")
            (m :n :t))
      (bind (a "\\")
            #(focus-or-open-tab-term)
            (desc "Terminal (tab)")
            (m :n :t))
      (bind (l "<leader>")
            #(pick :files)
            (desc "Fuzzy Files")
            (icon " " :yellow))
      (bind (l "/")
            #(pick :grep)
            (desc "Grep")
            (icon "󰓹 " :yellow))
      (bind (l ".")
            #(let [buf_name (vim.api.nvim_buf_get_name 0)
                   buf_dir (vim.fs.dirname buf_name)]
               (pick :files {:cwd buf_dir}))
            (desc "Fuzzy Files (buffer)")
            (icon " " :orange))
      (group
        :git
        (bind :g #(toggle_term :lazygit :lazygit) (desc "Lazygit")))
      (group
        :fuzzy
        ; keep-sorted start
        (bind ":" #(pick :command_history) (desc "Command history"))
        (bind ";" #(pick :commands) (desc "Commands"))
        (bind :H #(pick :highlights) (desc "Highlights"))
        (bind :I #(pick :icons) (desc "Icons"))
        (bind :L #(pick :lsp_config) (desc "LSP Config"))
        (bind :S #(pick :lsp_symbols) (desc "Symbols (buffer)"))
        (bind :b #(pick :buffers) (desc "Buffers"))
        (bind :c #(pick :cliphist) (desc "Cliphist"))
        (bind :d #(pick :diagnostics) (desc "Diagnostics"))
        (bind :h #(pick :help) (desc "Help Tags"))
        (bind :j #(pick :jumps) (desc "Jumps"))
        (bind :k #(pick :keymaps) (desc "Keymaps"))
        (bind :m #(pick :man) (desc "Man pages"))
        (bind :p #(pick :projects) (desc "Projects"))
        (bind :r #(pick :recent) (desc "Recent"))
        (bind :s #(pick :lsp_workspace_symbols) (desc "Symbols")))
      ; keep-sorted end
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
