(import-macros {: p! : do-req} :./lib/init-macros)

[(p! :nvim-mini/mini.ai
     (version :*)
     (opts true))
 (p! :nvim-mini/mini.bufremove
     (version :*)
     (keys
       (group
         :buffer
         (bind :d #(MiniBufremove.delete) (desc "Delete buffer"))))
     (opts {:silent true}))
 (p! :nvim-mini/mini.extra
     (version :*)
     (opts true))
 (p! :nvim-mini/mini.pairs
     (version :*)
     (event :VeryLazy)
     (opts {:modes {:command true}}))
 (p! :nvim-mini/mini.misc
     (version :*)
     (config (fn []
               (do-req :mini.misc :setup {})
               ;; restore last cursor pos
               (MiniMisc.setup_restore_cursor)
               ;; sync term bg
               (MiniMisc.setup_termbg_sync))))
 (p! :nvim-mini/mini.basics
     (lazy false)
     (version :*)
     (opts
       {:options {; basic options - not needed
                  :basic false
                  ; visual stuff
                  :extra_ui true
                  :win_borders :solid}
        :mappings {; <C-s> save
                   :basic true
                   ; <C-hjkl> window nav mappings are declared in
                   ; plugins/keys/_keymap.fnl for terminal-mode support
                   :windows false
                   ; disable <M-hjkl> cursor nav in insert/command modes
                   :move_with_alt true}}))]
