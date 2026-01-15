{
  nx = {
    pkgs,
    lib,
    ...
  }: let
    inherit (lib.meta) getExe;
  in {
    xdg = {
      portal = {
        enable = true;
        extraPortals = lib.mkForce (
          with pkgs; [
            xdg-desktop-portal-wlr
            xdg-desktop-portal-gtk
          ]
        );
      };
    };

    programs.niri = {
      enable = true;
      # environment = {
      #   MOZ_ENABLE_WAYLAND = "1";
      #   XDG_CURRENT_DESKTOP = "niri";
      #   GDK_BACKEND = "wayland";
      #   CLUTTER_BACKEND = "wayland";
      # };
      # xwayland-satellite = {
      #   enable = true;
      #   path = getExe pkgs.xwayland-satellite;
      # };
    };
  };
}
