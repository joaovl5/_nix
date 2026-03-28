{
  hm = {pkgs, ...}: let
    pkg = pkgs.emacs-unstable;
    # pkg = pkgs.emacs-unstable-pgtk.overrideAttrs (old: {
    #   configureFlags =
    #     old.configureFlags
    #     ++ [
    #       # "--with-imagemagick"
    #       "--with-json"
    #       "--with-native-compilation=aot"
    #       # ''CFLAGS="-O2 -mtune=native -fomit-frame-pointer"''
    #     ];
    # });
  in {
    hybrid-links.links.emacs = {
      from = ./config;
      to = "~/.config/emacs";
    };

    services.emacs = {
      enable = true;
      client.enable = true;
      startWithUserSession = "graphical";
    };

    programs.emacs = {
      enable = true;
      package = pkg;
      extraPackages = epkgs:
        with epkgs; [
          org-roam
          parinfer-rust-mode
          # epkgs.emacsql-sqlite3
        ];
    };

    home.packages = with pkgs; [
      nerd-fonts.iosevka
      inter-nerdfont
      anonymous-pro-fonts
      poppler-utils
      vips
    ];
  };
}
