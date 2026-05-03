(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :folke/which-key.nvim
        {:lazy false
         ; :keys [(key :<leader>? #(do-req :which-key :show {:global false})
         ;             {:desc "List buffer-local keymaps"})]
         :config (fn []
                   (do-req :which-key :setup
                           {:preset :modern
                            :plugins {:spelling {:enabled false}}
                            :win {:title false
                                  :padding [1 1]
                                  :border :none
                                  :width {:max 80}}
                            :layout {:spacing 5 :width {:min 30}}
                            :delay 50})
                   (require :./keymaps))})

; :opts {:keys {:preset :modern
;               :plugins {:spelling {:enabled false}}
;               :win {:title true
;                     :title_pos :center
;                     :padding [0 0]
;                     :wo {:winblend 50}
;                     :width {:max 80}}
;               :layout {:spacing 5 :width {:min 30}}
;               :delay 150}}})
