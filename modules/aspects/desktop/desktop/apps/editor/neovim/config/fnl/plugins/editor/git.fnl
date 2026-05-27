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
   (deps [:esmuellert/codediff.nvim
          :m00qek/baleia.nvim])
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
      :commit_editor {:staged_diff_split_kind :auto}})
   {:enabled false})
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
