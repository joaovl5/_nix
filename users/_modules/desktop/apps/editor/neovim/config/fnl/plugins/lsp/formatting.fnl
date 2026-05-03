(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(local formatters {:prettierd {:command :prettierd}
                   :fnlfmt {:command :fnlfmt}
                   :alejandra {:command :alejandra}
                   :nix_fmt {:command :nix :args [:fmt]}})

(local default_formatters_by_ft
       {:python [:ruff_fix :ruff_format :ruff_organize_imports]
        :typescript [:prettierd]
        :javascript [:prettierd]
        :typescriptreact [:prettierd]
        :handlebars [:prettierd]
        :lua [:stylua]
        :fennel [:fnlfmt]
        :nix [:alejandra]
        :rust [:rust_fmt]
        :toml [:taplo]
        :markdown [:prettierd]})

(fn get_project_formatters_by_ft [bufnr]
  (let [(ok neoconf) (pcall require :neoconf)]
    (if ok
        (neoconf.get :formatter.filetypes {}
                     {:buffer bufnr :local true :global false})
        {})))

(fn resolve_formatters_for_ft [bufnr filetype]
  (let [project_map (get_project_formatters_by_ft bufnr)
        override (. project_map filetype)]
    (if (vim.islist override)
        override
        (. default_formatters_by_ft filetype))))

(local formatters_by_ft
       {:python #(resolve_formatters_for_ft $1 :python)
        :typescript #(resolve_formatters_for_ft $1 :typescript)
        :javascript #(resolve_formatters_for_ft $1 :javascript)
        :typescriptreact #(resolve_formatters_for_ft $1 :typescriptreact)
        :handlebars #(resolve_formatters_for_ft $1 :handlebars)
        :lua #(resolve_formatters_for_ft $1 :lua)
        :fennel #(resolve_formatters_for_ft $1 :fennel)
        :nix #(resolve_formatters_for_ft $1 :nix)
        :rust #(resolve_formatters_for_ft $1 :rust)
        :toml #(resolve_formatters_for_ft $1 :toml)
        :markdown #(resolve_formatters_for_ft $1 :markdown)})

(plugin :stevearc/conform.nvim
        {:dependencies [:folke/neoconf.nvim]
         :opts {: formatters
                : formatters_by_ft
                :format_on_save {:timeout_ms 3000 :lsp_format :fallback}}})
