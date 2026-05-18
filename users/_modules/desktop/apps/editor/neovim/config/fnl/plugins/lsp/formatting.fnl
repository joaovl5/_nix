(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)

(local formatters
       {; keep-sorted start
        :alejandra {:command :alejandra}
        :jandent {:command :jindt :stdin true}
        :kdlfmt {:command :kdlfmt :args [:format :--kdl-version :v1 :--stdin]}
        :nix_fmt {:command :nix :args [:fmt]}
        :prettierd {:command :prettierd}
        :sane_fnlfmt {:command :fnlfmt :args [:-]}})

; keep-sorted end

(local default_formatters_by_ft
       {; keep-sorted start
        :* [:keep-sorted]
        :_ [:trim_whitespace :trim_newlines :squeeze_blanks]
        :dockerfile [:dockerfmt]
        :fennel [:sane_fnlfmt]
        :fish [:fish_indent]
        :handlebars [:prettierd]
        :janet [:jandent :squeeze_blanks]
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
  (let [(ok neoconf)
        (pcall require :neoconf)]
    (if ok
        (neoconf.get :formatter.filetypes
                     {}
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

(p! :stevearc/conform.nvim
    (deps [:folke/neoconf.nvim])
    (event :BufEnter)
    (keys
      (group
        :code
        (bind :f
              #(do-req :conform :format)
              (desc "Format"))))
    (opts {: formatters
           : formatters_by_ft
           :format_on_save {:timeout_ms 3000 :lsp_format :fallback}}))
