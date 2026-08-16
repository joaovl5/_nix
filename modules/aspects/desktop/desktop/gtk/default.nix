_: {
  den.aspects.desktop.homeManager = {
    pkgs,
    config,
    ...
  }: {
    home.pointerCursor = {
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 32;
    };
    gtk = {
      enable = true;

      font = {
        name = "Noto Sans";
        package = pkgs.noto-fonts;
        size = 14;
      };

      # FIXME: this got deprecated (iirc due to having unmaintained
      # gtk-2 dependencies) and gives an eval error; need to find some
      # other theme later

      # theme = {
      #   name = "Kanagawa-BL-LB";
      #   package = pkgs.kanagawa-gtk-theme;
      # };

      gtk4.theme = config.gtk.theme;

      gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
      gtk2.force = true;
    };
  };
}
