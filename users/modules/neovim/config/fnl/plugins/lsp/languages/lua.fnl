(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(add :folke/lazydev.nvim)
(do-req :lazydev :setup {:library {:path "${3rd}/luv/library"
                                   :words ["vim%.uv"]}})
