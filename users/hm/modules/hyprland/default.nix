{
  pkgs,
  inputs,
  ...
}: let
  package = pkgs.hyprland;
  displayManager = import ../display-manager.nix {
    inherit pkgs;
    default_cmd = "${package}/bin/Hyprland";
  };
in {
  imports = with inputs; [
    displayManager
  ];

  wayland.windowManager.hyprland = {
    inherit package;

    enable = true;
    systemd.enable = true;
    xwayland.enable = true;

    settings = {
      source = [];
    };
  };
}
