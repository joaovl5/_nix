{
  pkgs,
  system,
  ...
}: let
  # inherit (args) hyprland-plugins hyprland;
  # package = hyprland.packages.${system}.hyprland;
  # portal_package = hyprland.packages.${system}.xdg-desktop-portal-hyprland;
  # package = pkgs.hyprland;
in {
  # wayland.windowManager.hyprland = {
  #   # inherit package;
  #   enable = true;
  #   # disabled as it conflicts w/ UWSM
  #   # https://wiki.hypr.land/Useful-Utilities/Systemd-start/#uwsm
  #   systemd.enable = false;
  #   xwayland.enable = true;
  #
  #   # plugins = with hyprland-plugins.packages.${system}; [
  #   #   hyprexpo
  #   # ];
  #
  #   settings = {
  #     source = [];
  #   };
  # };
  #
  # # this executable is used by greetd to detect the default wayland session command
  # home.file.".wayland-session" = {
  #   source = "${package}/bin/Hyprland";
  #   executable = true;
  # };
}
