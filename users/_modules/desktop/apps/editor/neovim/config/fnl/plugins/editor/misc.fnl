(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)

[(p!
   :folke/zen-mode.nvim
   (keys
     (group
       :window
       (bind :z #(do-req :zen-mode :toggle {}))))
   (opts {:window {:backdrop 1 :width 110 :height 1}
          :plugins {:options {:enabled true
                              :ruler true
                              :showcmd false
                              :laststatus 0}
                    :twilight {:enabled false}
                    :gitsigns {:enabled true}
                    :tmux {:enabled true}}}))]
