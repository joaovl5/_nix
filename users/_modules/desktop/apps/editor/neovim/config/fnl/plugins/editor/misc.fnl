(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)

[(p!
   :karb94/neoscroll.nvim
   (event :BufEnter)
   (opts {:cursor_scrolls_alone false}))
 (p!
   :sphamba/smear-cursor.nvim
   (event :BufEnter)
   (opts {:stiffness 0.8
          :stiffness_insert_mode 0.7
          :trailing_stiffness 0.6
          :trailing_stiffness_insert_mode 0.7
          :damping 0.95
          :damping_insert_mode 0.95
          :distance_stop_animating 0.5
          :time_interval 7}))
 (p!
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
