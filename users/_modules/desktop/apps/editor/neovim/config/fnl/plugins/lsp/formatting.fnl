(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(local formatters {; keep-sorted start
                   :alejandra {:command :alejandra}
                   :fnlfmt {:command :fnlfmt}
                   :kdlfmt {:command :kdlfmt
                            :args [:format :--kdl-version :v1 :--stdin]}
                   :nix_fmt {:command :nix :args [:fmt]}
                   :prettierd {:command :prettierd}})

; keep-sorted end

(local default_formatters_by_ft
       {; keep-sorted start
        :* [:keep-sorted]
        :_ [:trim_whitespace :trim_newlines :squeeze_blanks]
        :dockerfile [:dockerfmt]
        :fennel [:fnlfmt]
        :fish [:fish_indent]
        :handlebars [:prettierd]
        :javascript [:prettierd]
        :json [:jsonfmt]
        :kdl [:kdlfmt]
        :kulala [:kulala-fmt]
        :lua [:stylua]
        :markdown [:rumdl]
        :nix [:alejandra]
        :python [:ruff_fix :ruff_format :ruff_organize_imports]
        :rust [:rust_fmt]
        :sh [:shfmt]
        :sql [:sqruff]
        :toml [:taplo]
        :typescript [:prettierd]
        :typescriptreact [:prettierd]
        :yaml [:yamlfmt]})

; keep-sorted end

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
       (let [ft-keys (vim.tbl_keys default_formatters_by_ft)]
         (collect [_ ft (ipairs ft-keys)]
           (values ft #(resolve_formatters_for_ft $1 ft)))))

(plugin :stevearc/conform.nvim
        {:dependencies [:folke/neoconf.nvim]
         :opts {: formatters
                : formatters_by_ft
                :format_on_save {:timeout_ms 3000 :lsp_format :fallback}}})
