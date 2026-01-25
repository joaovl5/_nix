(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(later (fn []
         (add {:source :nosduco/remote-sshfs.nvim
               :depends [:nvim-telescope/telescope.nvim :nvim-lua/plenary.nvim]})
         (do-req :remote-sshfs :setup {})
         (do-req :telescope :load_extension :remote-sshfs)))
