(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(let [zox_ev_action (fn [sel]
                      (vim.cmd.cd sel.path)
                      (MiniFiles.open sel.path))
      zox_ev_after_action (fn [sel]
                            (vim.notify (.. "Directory changed to `" sel.path
                                            "`")))
      zoxide_cfg {:prompt_title "∟ Zoxide Pick ⯾"
                  :mappings {:default {:action zox_ev_action
                                       :after_action zox_ev_after_action}}}]
  (plugin :nvim-telescope/telescope.nvim
          {:dependencies [:nvim-lua/popup.nvim
                          :nvim-lua/plenary.nvim
                          :jvgrootveld/telescope-zoxide]
           :opts {:zoxide zoxide_cfg}}))
