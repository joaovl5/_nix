{
  pkgs,
  config,
  inputs,
  lib,
  system,
  ...
}: let
  cfg = config.my_nix;
in {
  my_nix.technitium_dns.enable = true;
  my_nix.nextcloud.enable = true;
  my_nix.minio.enable = true;

  imports = with inputs; [
    hm.nixosModules.home-manager
    ./services/technitium-dns
    ./services/minio
    ./services/nextcloud
    ./services/syncthing
    ./services/traefik
  ];

  # environment.shells = [pkgs.fish];
  programs.fish.enable = true;

  users.users.${cfg.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "libvirt"];
    hashedPasswordFile = config.sops.secrets.password_hash.path;
    shell = pkgs.fish;
  };

  # allow sudo without password
  security.sudo.extraRules = [
    {
      users = [cfg.username];
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
