{
  hm = {
    pkgs,
    lib,
    ...
  }: let
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
    hybrid-links.links.neovim = {
      from = ./config;
      to = "~/.config/nvim";
    };

    programs.neovim = {
      enable = true;
      sideloadInitLua = true;
      initLua = lib.mkOrder 1001 ''
        _G.plugin_dirs = {}
        _G.header = [[
        ${lib.readFile ./assets/header.txt}]]
        _G.tsserver_path = "${pkgs.typescript}/lib/node_modules/typescript/bin/tsserver"

        ${add_rtp_lines}

        local local_lua = vim.fs.joinpath(vim.fn.stdpath("config"), "local.lua")
        if vim.fn.filereadable(local_lua) == 1 then
          dofile(local_lua)
        end
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
      imagemagick

      # language support
      gitleaks
      prettierd
      ## python
      ty
      basedpyright
      ruff
      (python3.withPackages (ps:
        with ps; [
          debugpy
        ]))
      ## js
      eslint_d
      typescript-language-server
      typescript
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
