(import-macros {: do-req : let-req : plugin : p! : key} :./lib/init-macros)
(local {: v/$} (require :lib/nvim))

(fn treewalker [subcommand]
  (let [(ok err) (pcall v/$ (.. "Treewalker " subcommand))]
    (when (not ok)
      (if (and (= :string (type err))
               (string.find err
                            "Treewalker: Treesitter node not found under cursor"
                            1
                            true))
          (vim.notify "Treewalker: no Treesitter node under cursor"
                      vim.log.levels.WARN)
          (error err)))))

[; relative line nums will only include digits 1 throught 5 for comfort)
 (plugin :mluders/comfy-line-numbers.nvim {:opts true :event :BufEnter})
 ; flash
 (let [flash-exclude
       [:notify
        :cmp_menu
        :noice
        :flash_prompt
        :codediff-explorer]
       flash-key-specs
       [{1 :s
         2 (fn [] (do-req :flash :jump))
         :mode [:n :x :o]}
        {1 :S
         2 (fn [] (do-req :flash :treesitter))
         :mode [:n :x :o]}
        {1 :r
         2 (fn [] (do-req :flash :remote))
         :mode [:o]
         :desc "Remote flash"}]
       registered-flash-buffers {}
       flash-filetype?
       (fn [filetype]
         (accumulate [matches? false
                      _ excluded (ipairs flash-exclude)
                      &until matches?]
           (= excluded filetype)))
       flash-excluded-buffer?
       (fn [bufnr]
         (flash-filetype?
           (vim.api.nvim_get_option_value
             :filetype
             {:buf bufnr})))
       register-flash-keys!
       (fn [bufnr]
         (when (not (. registered-flash-buffers bufnr))
           (each [_ spec (ipairs flash-key-specs)]
             (vim.keymap.set spec.mode
                             (. spec 1)
                             (. spec 2)
                             {:buffer bufnr
                              :desc spec.desc}))
           (tset registered-flash-buffers bufnr true)))
       delete-flash-keys!
       (fn [bufnr]
         (when (. registered-flash-buffers bufnr)
           (each [_ spec (ipairs flash-key-specs)]
             (each [_ mode (ipairs spec.mode)]
               (pcall vim.keymap.del
                      mode
                      (. spec 1)
                      {:buffer bufnr})))
           (tset registered-flash-buffers bufnr nil)))
       sync-flash-keys!
       (fn [bufnr]
         (when (vim.api.nvim_buf_is_valid bufnr)
           (if (flash-excluded-buffer? bufnr)
               (delete-flash-keys! bufnr)
               (register-flash-keys! bufnr))))]
   (p! :folke/flash.nvim
       (event :BufEnter)
       (init
         (fn []
           (let [group (vim.api.nvim_create_augroup
                         :MyFlashKeys
                         {:clear true})]
             (each [_ bufnr (ipairs (vim.api.nvim_list_bufs))]
               (sync-flash-keys! bufnr))
             (vim.api.nvim_create_autocmd
               [:BufEnter :FileType]
               {:group group
                :callback (fn [event]
                            (sync-flash-keys! event.buf))}))))
       (opts
         (let [keys :fhdjskalgrueiwoqptvnmb]
           {:labels keys
            :search {:multi_window false
                     :forward true
                     :wrap true
                     :exclude [(fn [win]
                                 (not (. (vim.api.nvim_win_get_config win)
                                         :focusable)))
                               (unpack flash-exclude)]
                     :mode :fuzzy}
            :jump {:nohlsearch true :autojump true}
            :label {:uppercase false :distance true}
            :highlight {:backdrop true}
            :modes {:char {:enabled false}
                    :treesitter {:labels keys
                                 :highlight {:backdrop true
                                             :matches false}}}}))))
 ; spider (improved w,e,b motions)
 (p! :chrisgrieser/nvim-spider
     (keys
       (bind :w
             (fn [] (do-req :spider :motion :w))
             (m :n :x :o))
       (bind :e
             (fn [] (do-req :spider :motion :e))
             (m :n :x :o))
       (bind :b
             (fn [] (do-req :spider :motion :b))
             (m :n :x :o)))
     (opts true))
 ; monkey-like crazyness
 (p! :aaronik/treewalker.nvim
     (cmd :Treewalker)
     (keys
       (bind "<A-[>" (fn [] (treewalker :Left)) (m :n :x))
       (bind "<A-]>" (fn [] (treewalker :Right)) (m :n :x))
       (bind :<A-k> (fn [] (treewalker :Up)) (m :n :x))
       (bind :<A-j> (fn [] (treewalker :Down)) (m :n :x))
       (bind "<A-S-[>" (fn [] (treewalker :SwapLeft)) (m :n :x))
       (bind "<A-S-]>" (fn [] (treewalker :SwapRight)) (m :n :x))
       (bind :<A-K> (fn [] (treewalker :SwapUp)) (m :n :x))
       (bind :<A-J> (fn [] (treewalker :SwapDown)) (m :n :x)))
     (opts {}))]
