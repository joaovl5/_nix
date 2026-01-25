(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(local n (require :lib/nvim))

(add :AckslD/swenv.nvim)
(do-req :swenv :setup {:post_set_venv #(vim.cmd :LspRestart)})
(n.autocmd :FileType {:pattern [:python]
                      :callback (fn []
                                  (do-req :swenv.api :auto_venv)
                                  (vim.cmd :LspRestart))})
