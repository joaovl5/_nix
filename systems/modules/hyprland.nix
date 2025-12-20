{
  pkgs,
  lib,
  ...
}: let
  displayManager = import ./display-manager.nix {
    default_cmd = "${pkgs.hyprland}/bin/Hyprland";
  };
in {
  imports = [
    displayManager
  ];

  programs.dconf.enable = true;
  programs.hyprland.enable = true;

  # allows Hyprland to run without root privileges
  seatd.enable = true;
}
