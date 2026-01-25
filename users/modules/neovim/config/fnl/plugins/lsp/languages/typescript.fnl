(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(add {:source :pmizio/typescript-tools.nvim
      :depends [:nvim-lua/plenary.nvim :neovim/nvim-lspconfig]})

(do-req :typescript-tools :setup)
