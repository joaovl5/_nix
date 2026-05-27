(import-macros {: p!} :./lib/init-macros)

(p! :folke/neoconf.nvim
    (event :VeryLazy)
    (opts {:local_settings :.neoconf.json
           :global_settings :neoconf.json
           :live_reload false
           :plugins {:lspconfig {:enabled false}
                     :jsonls {:enabled false}
                     :lua_ls {:enabled false}}
           :import {:vscode false :coc false :nlsp false}}))
