(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[(plugin :folke/zen-mode.nvim
         {:dependencies [:folke/twilight.nvim]
          :opts {:window {:backdrop 1 :width 110 :height 1}}
          :plugins {:options {:enabled true
                              :ruler true
                              :showcmd false
                              :laststatus 0}
                    :twilight {:enabled true}
                    :gitsigns {:enabled true}
                    :tmux {:enabled true}}})]
