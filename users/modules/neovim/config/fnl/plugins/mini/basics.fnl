(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :nvim-mini/mini.basics
        {:version "*"
         :opts {:options {; basic options - not needed
                          :basic false
                          ; visual stuff
                          :extra_ui true
                          :win_borders :solid}}
         :mappings {; <C-s> save
                    :basic true
                    ; <C-hjkl> window nav mappings
                    :windows true
                    ; disable <M-hjkl> cursor nav in insert/command modes
                    :move_with_alt true}})
