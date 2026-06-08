(import-macros {: do-req : let-req : p! : i! : key} :./lib/init-macros)
(local {: v/n : v/later} (require :lib/nvim))

(fn handle_conf [x]
  (i! "Found conflicts!"))

; (v/later #(do-req :resolve :list_conflicts)))

[(p!
   ; git conflict resolver
   :spacedentist/resolve.nvim
   (event [:BufReadPre :BufNewFile])
   (keys
     (group
       :merge
       (bind :j (cmd :ResolveNext) (desc "Next Conflict"))
       (bind :k (cmd :ResolvePrev) (desc "Prev Conflict"))
       (bind :o (cmd :ResolveOurs) (desc "Use Ours"))
       (bind :t (cmd :ResolveTheirs) (desc "Use Theirs"))
       (bind :O (cmd :ResolveBoth) (desc "Use Both (ours first)"))
       (bind :T (cmd :ResolveBothReverse) (desc "Use Both (theirs first)"))
       (bind :b (cmd :ResolveBase) (desc "Use base"))
       (bind :n (cmd :ResolveNone) (desc "Use none"))
       (bind :l (cmd :ResolveList) (desc "List conflicts"))
       (bind :pt
             (cmd :ResolveDiffOursTheirs)
             (desc "Preview theirs"))
       (bind :po
             (cmd :ResolveDiffTheirsOurs)
             (desc "Preview ours"))))
   (opts {:default_keymaps false
          :on_conflict_detected handle_conf}))
 (p!
   :NeogitOrg/neogit
   (cmd :Neogit)
   (deps [:m00qek/baleia.nvim
          (p!
            :esmuellert/codediff.nvim
            (opts
              {:diff {:layout :inline
                      :cycle_next_hunk false
                      :cycle_next_file false}
               :explorer {:width 50
                          :view_mode :tree
                          :focus_on_select true}
               :keymaps {:view {:next_hunk "J"
                                :prev_hunk "K"
                                :next_file "L"
                                :prev_file "H"
                                :toggle_stage "-"
                                :stage_hunk "<A-s>"
                                :unstage_hunk "<A-u>"
                                :discard_hunk "<A-0>"
                                :align_move "<C-o>"
                                :toggle_layout "<C-t>"}}}))])
   (keys
     (group
       :git
       (bind :G (cmd :Neogit) (desc "Neogit"))
       (bind :c (cmd "Neogit commit") (desc "Commit"))
       (bind :l (cmd "Neogit log") (desc "Log"))))
   (opts
     ; TODO: change to kitty after migratinf off of foot to wezterm
     {:graph_style :unicode
      :process_spinner true
      :commit_editor {:staged_diff_split_kind :auto}}))
 (p!
   :lewis6991/gitsigns.nvim
   (opts {})
   (event :VeryLazy)
   (keys
     (group
       :git
       (bind :b
             (cmd "Gitsigns blame_line")
             (desc "Blame (line)"))
       (bind :B
             (cmd "Gitsigns blame")
             (desc "Blame")))))]
