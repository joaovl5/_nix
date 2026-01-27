(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)
(local n (require :lib/nvim))

(plugin :AckslD/swenv.nvim
        {:config (fn []
                   (do-req :swenv :setup {:post_set_venv #(vim.cmd :Lsp)})
                   (n.autocmd :FileType
                              {:pattern [:python]
                               :callback (fn []
                                           (do-req :swenv.api :auto_venv))}))})
