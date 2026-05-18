(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)
(local {: v/extend} (require :lib/nvim))


(plugin :zaldih/themery.nvim ; collect theme names
        {:lazy false
         :config (fn []
                   (local theme_names
                          (accumulate [all_names [] _ theme (ipairs (or _G.Config.themes
                                                                        []))]
                            (v/extend all_names theme.names)))
                   (do-req :themery
                           :setup
                           {:themes theme_names :livePreview true}))})
