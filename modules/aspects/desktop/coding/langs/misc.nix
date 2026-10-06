_: {
  den.aspects.coding.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      ##### general stuff
      gitleaks
      keep-sorted
      prettierd
      lspmux

      ##### not general
      # keep-sorted start
      clang-tools
      dockerfmt
      kdlfmt
      kulala-fmt
      marksman
      rumdl
      sqruff
      # keep-sorted end

      ##### dependencies
      # keep-sorted start
      imagemagick
      tree-sitter
      # keep-sorted end
    ];
  };
}
