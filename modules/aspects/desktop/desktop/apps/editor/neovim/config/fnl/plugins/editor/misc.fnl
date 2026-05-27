(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)

[; (p!
 ;   :karb94/neoscroll.nvim
 ;   (event :BufEnter)
 ;   (opts {:cursor_scrolls_alone false}))
 ; (p!
 ;   :sphamba/smear-cursor.nvim
 ;   (event :BufEnter)
 ;   (opts {:stiffness 0.8
 ;          :stiffness_insert_mode 0.7
 ;          :trailing_stiffness 0.6
 ;          :trailing_stiffness_insert_mode 0.7
 ;          :damping 0.95
 ;          :damping_insert_mode 0.95
 ;          :distance_stop_animating 0.5
 ;          :time_interval 7}))
 (p!
   :rmagatti/auto-session
   (lazy false)
   (keys
     (group
       :session
       (bind :s (cmd "AutoSession save") (desc "Save session"))
       (bind :t (cmd "AutoSession toggle") (desc "Toggle autosave"))
       (bind :f (cmd "AutoSession search") (desc "Pick sessions"))))
   (opts
     {:session_lens {:picker :snacks}
      :cwd_change_handling true
      :git_use_branch_name true
      :git_auto_restore_on_branch_change true
      :bypass_save_filetypes [:alpha :dashboard :snacks_dashboard]}))
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
