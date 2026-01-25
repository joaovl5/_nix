(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(now (fn []
       ;; noice ui rework
       (require :plugins.ui.noice)
       ;; statusline
       (require :plugins.ui.statusline)
       ;; color-related plugins
       (require :plugins.ui.colors)))
