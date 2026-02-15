{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.my.nix;
in {
  imports = [
    ../_modules/console
    ../_modules/security
    ../_modules/services/ntp.nix
    ../_modules/console
    {my_system.title = lib.readFile ./assets/title.txt;}
  ];

  networking = {
    hostName = lib.mkForce cfg.hostname;
  };

  users.mutableUsers = false;
  users.users.root = {
    hashedPassword = lib.mkForce null;
    hashedPasswordFile = config.sops.secrets.password_hash_server.path;
    shell = pkgs.bash;
  };

  # scans network, detects hostnames
  services.avahi.enable = true;
  # ssh daemon and agent
  services.openssh = {
    enable = true;

    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # disable privileged ports
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
  virtualisation = {
    spiceUSBRedirection.enable = true;
    containers.enable = true;
    docker = {
      enable = false; # we use rootless instead
      # storageDriver = "btrfs";
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
    libvirtd.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # virtualisation
    docker
    docker-compose

    # utils
    dconf
    curl
    wget
    git
    btop
    wget
  ];

  system.stateVersion = "25.11";
}
