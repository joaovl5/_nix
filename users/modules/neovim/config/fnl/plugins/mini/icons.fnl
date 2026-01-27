(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :nvim-mini/mini.icons
        {:version "*"
         :event :VeryLazy
         :config #(let [icons (require :mini.icons)]
                    (icons.setup {})
                    (MiniIcons.mock_nvim_web_devicons)
                    (MiniIcons.tweak_lsp_kind))})
