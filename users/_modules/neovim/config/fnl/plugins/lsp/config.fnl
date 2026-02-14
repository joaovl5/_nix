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

(fn populate_diagnostics [client bufnr]
  (do-req :workspace-diagnostics :populate_workspace_diagnostics client bufnr))

(fn do_basedpyright_attach [client bufnr]
  (n.usercmd bufnr :LspPyrightOrganizeImports {:desc "Organize Imports"}
             #(client:exec_cmd {:command :basedpyright.organizeimports
                                :arguments {vim.uri_from_bufnr bufnr}}))
  (n.usercmd bufnr :LspPyrightSetPythonPath
             {:desc "Set Python Path" :nargs 1 :complete :file} set_python_path)
  (populate_diagnostics client bufnr))

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
        blink (require :blink.cmp)
        servers {:basedpyright {:on_attach do_basedpyright_attach
                                :settings {:basedpyright {:analysis {:autoSearchPaths true
                                                                     :useLibraryCodeForTypes true
                                                                     :typeCheckingMode :recommended
                                                                     :diagnosticMode :workspace
                                                                     :reportUnknownParameterType false
                                                                     :reportExplicitAny false}}}}
                 :ruff {:server_capabilities {:hoverProvider false}}
                 :lua_ls {:cmd [:lua-language-server]
                          :settings {:Lua {:completion {:callSnippet :Replace}}}}
                 :fennel_ls {:cmd [:fennel-ls]
                             :single_file_support true
                             :root_dir get_fennel_root_dir}
                 :jsonls {:cmd [:jsonls]
                          :settings {:json {:schemas (schemastore.json.schemas)}}}
                 :nixd {:cmd [:nixd]
                        :settings {:nixd {:nixpkgs {:expr "import <nixpkgs> {}"}
                                          :formatting {:command [:alejandra]}
                                          :options {:home-manager {;; In case of using home-manager standalone, replace to:
                                                                   ;;  "expr": "(builtins.getFlake (builtins.toString ./.)).homeConfigurations.<name>.options"
                                                                   :expr "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.<name>.options.home-manager.users.type.getSubOptions []"}
                                                    :nixos {:expr (let [nixos_hostname :lavpc]
                                                                    (.. "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations."
                                                                        nixos_hostname
                                                                        :.options))}}}}}
                 ; :taplo {:cmd [:taplo]}
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
      (vim.lsp.config server config)
      (vim.lsp.config server (blink.get_lsp_capabilities))
      (vim.lsp.config server {:on_attach populate_diagnostics})
      (vim.lsp.enable server))))

[(plugin :nvimtools/none-ls.nvim
         {:dependencies [:nvim-lua/plenary.nvim :nvimtools/none-ls-extras.nvim]
          :opts (fn []
                  (let [nu (. (require :null-ls) :builtins)
                        no #(require (.. :none-ls. $1))]
                    {:sources [; general 
                               nu.diagnostics.gitleaks
                               nu.diagnostics.proselint
                               nu.hover.dictionary
                               ; dockerfile
                               nu.diagnostics.hadolint
                               ; .sh
                               nu.hover.printenv
                               ; fish
                               nu.diagnostics.fish
                               ; nix 
                               nu.formatting.alejandra
                               nu.diagnostics.statix
                               nu.code_actions.statix
                               nu.diagnostics.deadnix
                               ; python
                               ;; TODO: ^0 setup mypy to use it : nu.diagnostics.mypy
                               ; js-like
                               nu.formatting.prettierd
                               (no :formatting.jq)
                               (no :diagnostics.eslint_d)
                               (no :code_actions.eslint_d)]}))})
 (plugin :neovim/nvim-lspconfig
         {:config mk_lsp
          :dependencies [:b0o/schemastore.nvim
                         (plugin ":artemave/workspace-diagnostics.nvim"
                                 {:opts {}})]})]
