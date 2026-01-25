(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(later (fn []
         (add {:source :nvim-telescope/telescope.nvim
               :depends [:nvim-lua/popup.nvim :nvim-lua/plenary.nvim]})
         (add :jvgrootveld/telescope-zoxide)
         (let [ts (require :telescope)
               z_utils (require :telescope._extensions.zoxide.utils)]
           (ts.setup {:zoxide {:prompt_title "∟ Zoxide Pick ⯾"
                               :mappings {:default {:action (fn [sel]
                                                              (vim.cmd.cd sel.path)
                                                              (MiniFiles.open sel.path))
                                                    :after_action (fn [sel]
                                                                    (vim.notify (.. "Directory changed to "
                                                                                    sel.path)))}}}}))))
