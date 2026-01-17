{
  nx = {
    pkgs,
    lib,
    ...
  }: {
    xdg = {
      autostart.enable = true;
      mime.enable = true;
      portal = {
        enable = true;
        xdgOpenUsePortal = true;
        extraPortals = lib.mkForce (
          with pkgs; [
            xdg-desktop-portal-wlr
            xdg-desktop-portal-gtk
            gnome-keyring
          ]
        );
      };
    };
  };
}
