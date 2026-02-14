(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :nosduco/remote-sshfs.nvim
        {:depends [:nvim-telescope/telescope.nvim :nvim-lua/plenary.nvim]
         :event :VeryLazy
         :config (fn []
                   (do-req :remote-sshfs :setup {})
                   (do-req :telescope :load_extension :remote-sshfs))})
