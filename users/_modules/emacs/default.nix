{
  hm = {
    pkgs,
    config,
    nixos_config,
    ...
  }: let
    cfg = nixos_config.my.nix;
    flake_path = cfg.flake_location;
    here = assert (flake_path != null); "${flake_path}/users/_modules/emacs";
    configSrc = config.lib.file.mkOutOfStoreSymlink "${here}/config";

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
    xdg.configFile."emacs" = {
      source = configSrc;
      recursive = true;
      force = true;
    };

    services.emacs = {
      enable = true;
      client.enable = true;
      startWithUserSession = "graphical";
    };

    programs.emacs = {
      enable = true;
      package = pkg;
      extraPackages = epkgs: [
        epkgs.org-roam
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
