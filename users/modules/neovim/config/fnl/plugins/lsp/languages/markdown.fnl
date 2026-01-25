(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(add :OXY2DEV/markview.nvim)
(do-req :markview :setup
        {:preview {:filetypes [:markdown :quarto :rmd :typst :Avante]
                   :icon_provider :mini}})
