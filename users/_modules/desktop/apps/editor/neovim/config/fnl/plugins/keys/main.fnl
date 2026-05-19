(import-macros {: do-req : p!} :./lib/init-macros)

(p! :folke/which-key.nvim
    (lazy false)
    (priority 999)
    (config
      (fn []
        (let [wk (require :which-key)
              k (require :lib.keys)]
          (wk.setup (require :plugins.keys._whichkey))
          (k.register-plugin-icons!))
        (require :plugins.keys._keymap))))
