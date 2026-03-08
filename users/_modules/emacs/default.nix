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
      package = pkgs.emacs-unstable-pgtk;
      # extraPackages = _: [
      #   pkgs.nerd-fonts.iosevka
      # ];
    };

    home.packages = with pkgs; [
      nerd-fonts.iosevka
    ];
  };
}
