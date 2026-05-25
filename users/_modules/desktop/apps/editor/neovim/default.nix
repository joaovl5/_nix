{
  hm = {
    pkgs,
    lib,
    inputs,
    ...
  }: let
    treesitter = let
      nts = pkgs.vimPlugins.nvim-treesitter;
      kanataGrammar = pkgs.tree-sitter.buildGrammar {
        language = "kanata";
        version = "0.1.0+${inputs.tree-sitter-kanata.shortRev}";
        src = inputs.tree-sitter-kanata;
        # Neovim evaluates #match? with Vim regex; escape literal @ in upstream query.
        postPatch = ''
          substituteInPlace queries/highlights.scm \
            --replace-fail '"@.+"' '"\\@.+"'
        '';
      };
    in
      nts.withPlugins (_: nts.allGrammars ++ [kanataGrammar]);

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

    add_rtp_lines = lib.join "\n" (
      lib.mapAttrsToList
      (name: package: ''
        vim.opt.runtimepath:append('${package}')
        _G.plugin_dirs['${name}'] = '${package}'
      '')
      (
        plugins_set
        // {
          inherit grammarsPath;
        }
      )
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
        lua5_1
        luarocks
      ];
    };

    home.packages = with pkgs; [
      neovide
      neovim-remote
    ];
  };
}
