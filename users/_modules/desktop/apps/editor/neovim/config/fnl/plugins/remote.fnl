(import-macros {: do-req : p!} :./lib/init-macros)

[]
; (p! :nosduco/remote-sshfs.nvim
;     (deps [:nvim-telescope/telescope.nvim :nvim-lua/plenary.nvim])
;     (event :VeryLazy)
;     (config (fn []
;               (do-req :remote-sshfs :setup {})
;               (do-req :telescope :load_extension :remote-sshfs))))
