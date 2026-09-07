_: {
  den.aspects.desktop.homeManager = {
    pkgs,
    lib,
    inputs,
    ...
  }: let
    plugins_set = with pkgs.vimPlugins; {
      inherit
        parinfer-rust
        blink-cmp
        blink-pairs
        friendly-snippets
        lspkind-nvim
        colorful-menu-nvim
        ;
    };

    add_rtp_lines = lib.join "\n" (
      lib.mapAttrsToList
      (name: package: ''
        vim.opt.runtimepath:append('${package}')
        _G.plugin_dirs['${name}'] = '${package}'
      '')
      plugins_set
    );
  in {
    hybrid-links.links.neovim = {
      from = ./config;
      to = "~/.config/nvim";
    };

    hybrid-links.links.neovide = {
      from = ./neovide;
      to = "~/.config/neovide";
    };

    xdg.dataFile."fennel-ls/docsets/nvim.lua".source = inputs.fennel-ls-nvim-docs + "/nvim.lua";

    programs.neovim = {
      enable = true;
      # Neovim 0.12.4 refreshes semantic tokens throughout each typing burst.
      # Remove this patch after https://github.com/neovim/neovim/issues/41521 is fixed.
      package = pkgs.neovim-unwrapped.overrideAttrs (old: {
        patches = (old.patches or []) ++ [./semantic-tokens-debounce.patch];
      });
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
      withPython3 = true;
      withRuby = true;

      plugins = lib.attrValues plugins_set;

      extraLuaPackages = ps:
        with ps; [
          luarocks
          fennel
        ];
      extraPackages = with pkgs; [
        curl
        gcc
        gnutar
        lua5_1
        luarocks
        tree-sitter
      ];
    };

    shell-abbrs = {
      "n" = "nvim";
    };

    home.packages = with pkgs; [
      neovide
      neovim-remote
    ];
  };
}
