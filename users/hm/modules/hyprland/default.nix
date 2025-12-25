{
  pkgs,
  inputs,
  ...
}: let
  package = pkgs.hyprland;
in {
  wayland.windowManager.hyprland = {
    inherit package;

    enable = true;
    systemd.enable = true;
    xwayland.enable = true;

    settings = {
      source = [];
    };
  };

  # this executable is used by greetd to detect the default wayland session command
  home.file.".wayland-session" = {
    source = "${package}/bin/Hyprland";
    executable = true;
  };
}
