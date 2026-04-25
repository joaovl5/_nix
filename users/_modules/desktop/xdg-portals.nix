{
  hm = {
    pkgs,
    lib,
    ...
  }: {
    xdg = {
      configFile."electron-flags.conf".text = ''
        --enable-features=UseOzonePlatform
        --ozone-platform=wayland
      '';

      autostart.enable = true;
      mime.enable = true;
      portal = {
        enable = lib.mkForce true;
        xdgOpenUsePortal = true;
        extraPortals = lib.mkForce (
          with pkgs; [
            xdg-desktop-portal-gnome
            # gnome-keyring
          ]
        );
        config.common.default = lib.mkForce "gnome";
      };
    };
  };
}
