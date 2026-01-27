{
  hm = {
    pkgs,
    config,
    nixos_config,
    ...
  }: let
    cfg = nixos_config.my_nix;
    flake_path = cfg.flake_location;
    here = assert (flake_path != null); "${flake_path}/users/modules/neovim";
    configSrc = config.lib.file.mkOutOfStoreSymlink "${here}/config";
  in {
    xdg.configFile."nvim/" = {
      source = configSrc;
      recursive = true;
    };

    programs.neovim = {
      defaultEditor = true;
      enable = true;
      viAlias = true;
      vimAlias = true;
      extraLuaPackages = ps: [
        ps.luarocks
        ps.fennel
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
      ];
    };

    home.packages = with pkgs; [
      # deps
      fd
      ripgrep

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
