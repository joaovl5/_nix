(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :nvim-mini/mini.misc
        {:version "*"
         :config (fn []
                   (do-req :mini.misc :setup {})
                   ;; restore last cursor position
                   (MiniMisc.setup_restore_cursor)
                   ;; sync term emu bg
                   (MiniMisc.setup_termbg_sync))})
