{lav, ...}: {
  den.aspects.desktop.homeManager = {pkgs, ...} @ args: {
    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false;
      configType = "hyprlang";
      xwayland.enable = true;
      package = null;
      portalPackage = pkgs.xdg-desktop-portal-wlr;
      settings = lav.desktop.wm.hyprland.settings args;
    };
  };
  den.aspects.desktop.nixos = {pkgs, ...}: let
    hyprland_pkg = pkgs.hyprland;
  in {
    programs.hyprland = {
      enable = true;
      package = hyprland_pkg;
      portalPackage = pkgs.xdg-desktop-portal-wlr;
      withUWSM = true;
    };
  };
}
