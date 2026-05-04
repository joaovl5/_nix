(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :zaldih/themery.nvim ; collect theme names
        {:lazy false
         :config (fn []
                   (local theme_names
                          (accumulate [all_names [] _ theme (ipairs (or _G.Config.themes
                                                                        []))]
                            (vim.list_extend all_names theme.names)))
                   (do-req :themery :setup
                           {:themes theme_names :livePreview true}))})
