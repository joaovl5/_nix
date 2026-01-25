(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(now (fn []
       (add :zaldih/themery.nvim) ; collect theme names
       (local theme_names
              (accumulate [all_names [] _ theme (ipairs (or _G.Config.themes []))]
                (vim.list_extend all_names theme.names)))
       (do-req :themery :setup {:themes theme_names :livePreview true})))
