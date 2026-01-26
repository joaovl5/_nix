(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(local n (require :lib/nvim))

(fn set_python_path [path]
  (let [clients (vim.lsp.get_clients {:bufnr (vim.api.nvim_get_current_buf)
                                      :name :basedpyright})]
    (each [_ client (ipairs clients)]
      (if (not= nil client.settings)
          (set client.settings.python
               (vim.tbl_deep_extend :force (or client.settings.python {})
                                    {:pythonPath path}))
          (set client.config.settings
               (vim.tbl_deep_extend :force (or client.config.settings {})
                                    {:python {:pythonPath path}})))
      (client.notify :workspace/didChangeConfiguration {:settings nil}))))

(fn do_basedpyright_attach [client bufnr]
  (n.usercmd bufnr :LspPyrightOrganizeImports {:desc "Organize Imports"}
             #(client:exec_cmd {:command :basedpyright.organizeimports
                                :arguments {vim.uri_from_bufnr bufnr}}))
  (n.usercmd bufnr :LspPyrightSetPythonPath
             {:desc "Set Python Path" :nargs 1 :complete :file} set_python_path))

(fn get_fennel_root_dir [bufnr on_dir]
  (let [fname (vim.api.nvim_buf_get_name bufnr)
        has_fls_cfg #(= :file (. (or (vim.uv.fs_stat (vim.fs.joinpath $1
                                                                      :flsproject.fnl))
                                     {}) :type))]
    (on_dir (or (: (vim.iter (vim.fs.parents fname)) :find has_fls_cfg)
                (vim.fs.root 0 :.git)))))

(fn mk_lsp []
  "Setup language servers."
  (let [schemastore (require :schemastore)
        blink_capabilities (do-req :blink.cmp :get_lsp_capabilities)
        servers {:basedpyright {:on_attach do_basedpyright_attach
                                :settings {:basedpyright {:analysis {:autoSearchPaths true
                                                                     :useLibraryCodeForTypes true
                                                                     :typeCheckingMode :recommended
                                                                     :diagnosticMode :workspace
                                                                     :reportUnknownParameterType false
                                                                     :reportExplicitAny false}}}}
                 :lua_ls {:cmd [:lua-language-server]
                          :settings {:Lua {:completion {:callSnippet :Replace}}}}
                 :fennel_ls {:cmd [:fennel-ls]
                             :single_file_support true
                             :root_dir get_fennel_root_dir}
                 :jsonls {:cmd [:jsonls]
                          :settings {:json {:schemas (schemastore.json.schemas)}}}
                 :nixd {:cmd [:nixd]}
                 :taplo {:cmd [:taplo]}
                 :marksman {:cmd [:marksman]}
                 :stylua {:cmd [:stylua]}
                 :yamlls {:cmd [:yaml-language-server]}
                 :nil {:cmd [:nil]
                       :filetypes [:nix]
                       :root_markers [:flake.nix :.git]
                       :settings {:nil {:nix {:flake {:autoArchive true
                                                      :autoEvalInputs true
                                                      :nixpkgsInputName :nixpkgs}}}}}}]
    (each [server config (pairs servers)]
      (set config.capabilities
           (vim.tbl_deep_extend :force (or config.capabilities {})
                                blink_capabilities))
      (vim.lsp.config server config)
      (vim.lsp.enable server))))

(plugin :neovim/nvim-lspconfig {:dependencies [:b0o/schemastore.nvim]
                                :config mk_lsp})
