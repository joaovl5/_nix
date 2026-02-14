{
  pkgs,
  config,
  inputs,
  ...
}: let
  cfg = config.my_nix;
in {
  my_nix = {
    technitium_dns.enable = true;
    nextcloud.enable = true;
    minio.enable = true;
  };

  imports = with inputs; [
    hm.nixosModules.home-manager
    ./_services/technitium-dns
    ./_services/minio
    ./_services/nextcloud
    ./_services/syncthing
    ./_services/traefik
  ];

  # environment.shells = [pkgs.fish];
  programs.fish.enable = true;

  users.users.${cfg.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "libvirt"];
    hashedPasswordFile = config.sops.secrets.password_hash_server.path;
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

  home-manager.users.tyrant = _: {
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
