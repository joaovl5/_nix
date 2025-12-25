{
  pkgs,
  inputs,
  lib,
  system,
  ...
}: let
  username = "plankton";
in {
  imports = with inputs; [
    hm.nixosModules.home-manager
  ];

  environment.shells = [pkgs.bash];
  programs.bash.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    linger = true; # needed for autostarting pods
    extraGroups = ["wheel" "podman" "libvirt"];
    initialPassword = "12";
    shell = pkgs.fish;
  };

  # allow sudo without password
  security.sudo.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  home-manager.users.${username} = {config, ...}: {
    home.stateVersion = "23.11";

    home.packages = with pkgs; [
      ## utils
      vim
    ];
  };
}
