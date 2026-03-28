(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[(plugin :folke/zen-mode.nvim
         {:opts {:window {:backdrop 1 :width 110 :height 1}}
          :plugins {:options {:enabled true
                              :ruler true
                              :showcmd false
                              :laststatus 0}
                    :twilight {:enabled false}
                    :gitsigns {:enabled true}
                    :tmux {:enabled true}}})]
