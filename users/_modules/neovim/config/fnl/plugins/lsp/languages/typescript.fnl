(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :pmizio/typescript-tools.nvim
        {:dependencies [:nvim-lua/plenary.nvim :neovim/nvim-lspconfig]
         :ft [:typescriptreact :typescript]
         :opts true})
