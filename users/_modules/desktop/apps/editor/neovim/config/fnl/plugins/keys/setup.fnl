(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)

(p! :folke/which-key.nvim
    (lazy false)
    (priority 999)
    (config
      (fn []
        (do-req :which-key
                :setup
                (require :plugins.keys._whichkey))
        (require :plugins.keys._keymap))))
