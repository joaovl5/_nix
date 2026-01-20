{
  hm = {
    pkgs,
    lib,
    ...
  }: {
    xdg = {
      autostart.enable = true;
      mime.enable = true;
      portal = {
        enable = lib.mkForce true;
        xdgOpenUsePortal = true;
        extraPortals = lib.mkForce (
          with pkgs; [
            xdg-desktop-portal-wlr
            # xdg-desktop-portal-gnome
            # gnome-keyring
          ]
        );
        config.common.default = lib.mkForce "*";
      };
    };

    # systemd.user.services.xdg-desktop-portal-gnome.requisite = lib.mkForce [];
  };
}
