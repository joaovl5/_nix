{
  hm = {
    pkgs,
    lib,
    config,
    nixos_config,
    ...
  }: let
    cfg = nixos_config.my_nix;
    flake_path = cfg.flake_location;
    here = assert (flake_path != null); "${flake_path}/users/_modules/neovim";
    configSrc = config.lib.file.mkOutOfStoreSymlink "${here}/config";
  in {
    # xdg.configFile."nvim" = {
    #   source = configSrc;
    #   recursive = true;
    #   force = true;
    # };

    programs.neovim = {
      enable = true;
      initLua = lib.mkOrder 1001 (lib.readFile ./init.lua);
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
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
      ];
    };

    home.packages = with pkgs; [
      # deps
      fd
      ripgrep
      tree-sitter

      # language support
      prettierd
      ## python
      basedmypy
      basedpyright
      ruff
      (python3.withPackages (ps: with ps; [debugpy]))
      ## rust
      # rust-analyzer
      # # clippy
      # rustfmt
      # vscode-extensions.vadimcn.vscode-lldb.adapter
      ## js
      eslint_d
      typescript-language-server
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
    ];
  };
}
