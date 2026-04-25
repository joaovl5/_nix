{
  nx = {pkgs, ...}: let
    hyprland_pkg = pkgs.hyprland;
  in {
    programs.hyprland = {
      enable = true;
      package = hyprland_pkg;
      portalPackage = pkgs.xdg-desktop-portal-wlr;
      withUWSM = true;
    };
  };

  hm = {pkgs, ...} @ args: {
    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false;
      xwayland.enable = true;
      package = null;
      portalPackage = pkgs.xdg-desktop-portal-wlr;
      settings = import ./settings args;
    };
  };
}
