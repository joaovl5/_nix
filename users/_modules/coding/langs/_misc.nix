{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      ##### general stuff
      gitleaks
      keep-sorted
      prettierd
      lspmux

      ##### not general
      # keep-sorted start
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
