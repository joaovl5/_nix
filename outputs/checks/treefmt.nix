_: {
  projectRootFile = "flake.nix";
  programs = {
    # nix
    alejandra.enable = true;
    deadnix.enable = true;
    statix.enable = true;
    flake-edit.enable = true;
    # fennel
    fnlfmt.enable = true;
    # python
    ruff-check.enable = true;
    ruff-format.enable = true;
    # js/md
    prettier.enable = true;
    # fish
    fish_indent.enable = true;
    # lua
    stylua.enable = true;
    # toml
    taplo.enable = true;
  };
}
