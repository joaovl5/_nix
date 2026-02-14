(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :rachartier/tiny-inline-diagnostic.nvim
        {:event :VeryLazy
         :priority 1000
         :config (fn []
                   (do-req :tiny-inline-diagnostic :setup
                           {:preset :powerline
                            :options {:multilines {:enabled true}
                                      :breakline {:enabled true}
                                      :show_all_diags_on_cursorline true
                                      :show_diags_only_under_cursor false
                                      :override_open_float true
                                      :severity [vim.diagnostic.severity.ERROR]}})
                   (vim.diagnostic.config {:virtual_text false}))})
