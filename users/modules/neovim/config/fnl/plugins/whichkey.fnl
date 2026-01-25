(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(add :folke/which-key.nvim)
(do-req :which-key :setup {:keys {}
                           :preset :modern
                           :plugins {:spelling {:enabled false}}
                           :win {:title true
                                 :title_pos :center
                                 :padding [0 0]
                                 :wo {:winblend 50}}
                           :layout {:spacing 5 :width {:min 30}}
                           :delay 150})
