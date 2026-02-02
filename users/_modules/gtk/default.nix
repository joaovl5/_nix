{
  hm = {
    pkgs,
    config,
    ...
  }: {
    home.pointerCursor = {
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

      theme = {
        name = "Kanagawa-BL-LB";
        package = pkgs.kanagawa-gtk-theme;
      };

      gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
      gtk2.force = true;
    };
  };
}
