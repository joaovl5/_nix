{
  pkgs,
  inputs,
  lib,
  system,
  ...
}: let
  username = "tyrant";
in {
  imports = with inputs; [
    hm.nixosModules.home-manager
    ./services/technitium-dns
  ];

  environment.shells = [pkgs.fish];
  programs.fish.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "libvirt"];
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

  home-manager.users.tyrant = {config, ...}: {
    home.stateVersion = "23.11";

    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
    };

    home.packages = with pkgs; [
      # deps
      pinentry-curses

      ## utils
      ripgrep
      neovim
    ];
  };
}
