_: {
  den.aspects.desktop.homeManager = {pkgs, ...}: let
    pkg = pkgs.emacs;
    citre_tools = pkgs.runCommand "citre-tools" {} ''
      mkdir -p $out/bin
      ln -s ${pkgs.universal-ctags}/bin/readtags $out/bin/readtags
      ln -s ${pkgs.universal-ctags}/bin/universal-ctags $out/bin/universal-ctags
    '';
  in {
    hybrid-links.links.emacs = {
      from = ./config;
      to = "~/.config/emacs";
    };

    programs.emacs = {
      enable = true;
      package = pkg;
      extraPackages = epkgs:
        with epkgs; [
          org-roam
          vterm
          # parinfer-rust-mode
        ];
    };

    home.packages = with pkgs; [
      citre_tools
      global
      poppler-utils
      vips
    ];
  };
}
