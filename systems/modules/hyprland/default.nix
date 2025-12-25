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
    hm.nixosModules.home-manager
    displayManager
  ];

  config = {
    programs.dconf.enable = true;
    programs.hyprland.enable = true;

    wayland.windowManager.hyprland = {
      inherit package;

      enable = true;
      systemd.enable = true;
      xwayland.enable = true;

      settings = {
        source = [];
      };
    };
  };
}
