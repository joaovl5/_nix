(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :nvim-mini/mini.surround
        {:version "*"
         :opts {:highlight_duration 1000
                :mappings {:add :ra
                           :delete :rd
                           :find :rf
                           :find_left :rF
                           :highlight :rh
                           :replace :rr}}})
