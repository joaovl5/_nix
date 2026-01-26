(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :stevearc/conform.nvim
        {:opts {:formatters {:prettierd {:command :prettierd}
                             :fnlfmt {:command :fnlfmt}
                             :alejandra {:command :alejandra}}
                :formatters_by_ft {:python [:ruff_format]
                                   :typescript [:prettierd]
                                   :javascript [:prettierd]
                                   :typescriptreact [:prettierd]
                                   :handlebars [:prettierd]
                                   :lua [:stylua]
                                   :fennel [:fnlfmt]
                                   :nix [:alejandra]
                                   :rust [:rust_fmt]
                                   :markdown [:prettierd]}
                :format_on_save {:timeout_ms 3000 :lsp_format :fallback}}})
