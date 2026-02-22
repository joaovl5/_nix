{
  hm = {
    pkgs,
    lib,
    # config,
    # nixos_config,
    ...
  }: let
    # cfg = nixos_config.my.nix;
    # flake_path = cfg.flake_location;
    # here = assert (flake_path != null); "${flake_path}/users/_modules/neovim";
    # configSrc = config.lib.file.mkOutOfStoreSymlink "${here}/config";
    treesitter = let
      nts = pkgs.vimPlugins.nvim-treesitter;
    in
      nts.withPlugins (_: nts.allGrammars);

    grammarsPath = pkgs.symlinkJoin {
      name = "nvim-treesitter-grammars";
      paths = treesitter.dependencies;
    };

    plugins_set =
      {
        inherit treesitter;
      }
      // (with pkgs.vimPlugins; {
        inherit
          parinfer-rust
          blink-cmp
          blink-pairs
          friendly-snippets
          lspkind-nvim
          colorful-menu-nvim
          ;
      });

    add_rtp_lines = lib.join "\n" (lib.mapAttrsToList (name: package: ''
        vim.opt.runtimepath:append('${package}')
        _G.plugin_dirs['${name}'] = '${package}'
      '') (plugins_set
        // {
          inherit grammarsPath;
        }));
  in {
    # xdg.configFile."nvim" = {
    #   source = configSrc;
    #   recursive = true;
    #   force = true;
    # };

    programs.neovim = {
      enable = true;
      initLua = lib.mkOrder 1001 ''
        _G.plugin_dirs = {}
        _G.header = [[
        ${lib.readFile ./assets/header.txt}]]

        ${add_rtp_lines}

        ${lib.readFile ./init.lua}
      '';
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;

      plugins = lib.attrValues plugins_set;

      extraLuaPackages = ps:
        with ps; [
          luarocks
          fennel
        ];
      extraPackages = with pkgs; [
        (with fenix;
          complete.withComponents [
            "cargo"
            "clippy"
            "rust-src"
            "rustc"
            "rustfmt"
          ])
        rust-analyzer-nightly
        tree-sitter
        lua5_1
        luarocks
      ];
    };

    home.packages = with pkgs; [
      # deps
      fd
      ripgrep
      tree-sitter
      curl

      # language support
      gitleaks
      prettierd
      ## python
      ty
      basedpyright
      ruff
      (python3.withPackages (ps: with ps; [debugpy]))
      ## js
      eslint_d
      typescript-language-server
      vscode-js-debug
      ## nix
      alejandra
      nixd
      nil
      statix
      ## yaml
      yaml-language-server
      ## toml
      taplo
      ## markdown
      marksman
      ## dockerfile
      hadolint
    ];
  };
}
