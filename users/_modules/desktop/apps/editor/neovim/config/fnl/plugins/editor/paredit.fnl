(import-macros {: do-req : let-req : ft-keys! : p! : key} :./lib/init-macros)

(local fts
       [:fennel])

(fn pe [name ...]
  (do-req :nvim-paredit.api name ...))

(ft-keys!
  fts
  (bind ">l" #(pe :slurp_forwards) (desc "Slurp forwards"))
  (bind ">h" #(pe :slurp_backwards) (desc "Slurp backwards"))
  (bind "<l" #(pe :barf_forwards) (desc "Barf forwards"))
  (bind "<h" #(pe :barf_backwards) (desc "Barf backwards"))
  (bind ">e" #(pe :drag_element_forwards) (desc "Drag element forwards"))
  (bind "<e" #(pe :drag_element_backwards) (desc "Drag element backwards"))
  (bind ">p" #(pe :drag_pair_forwards) (desc "Drag pair forwards"))
  (bind "<p" #(pe :drag_pair_backwards) (desc "Drag pair backwards"))
  (bind ">f" #(pe :drag_form_forwards) (desc "Drag form forwards"))
  (bind "<f" #(pe :drag_form_backwards) (desc "Drag form backwards"))
  (bind "^f" #(pe :raise_form) (desc "Raise form"))
  (bind "^e" #(pe :raise_element) (desc "Raise element"))
  (with-mode [:n :x :o :v]
    (bind "E" #(pe :move_to_next_element_tail) (desc "Jump to next el. tail"))
    (bind "W" #(pe :move_to_next_element_head) (desc "Jump to next el. head"))
    (bind "B" #(pe :move_to_prev_element_head) (desc "Jump to prev el. head"))
    (bind "gE" #(pe :move_to_prev_element_tail) (desc "Jump to prev el. tail")))
  (with-mode [:n :x :v]
    (bind "("
          #(pe :move_to_parent_form_start)
          (desc "Go to parent head"))
    (bind ")"
          #(pe :move_to_parent_form_end)
          (desc "Go to parent tail"))
    (bind "T"
          #(pe :move_to_top_level_form_head)
          (desc "Go to top-level head")))
  (with-mode [:o :v]
    (bind :af #(pe :select_around_form) (desc "Around form"))
    (bind :if #(pe :select_in_form) (desc "In form"))
    (bind :aF #(pe :select_in_top_level_form) (desc "In top-level form"))
    (bind :ae #(pe :select_element) (desc "Around element"))
    (bind :ie #(pe :select_element) (desc "In element"))))

(p!
  :julienvincent/nvim-paredit
  (event :VeryLazy)
  (opts {:use_default_keys false}))
