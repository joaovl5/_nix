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
    hashedPasswordFile = config.sops.secrets.password_hash_server.path;
    shell = pkgs.bash;
  };

  # scans network, detects hostnames
  services.avahi.enable = true;
  # ssh daemon and agent
  services.openssh = {
    enable = true;

    settings = {
      PermitRootLogin = "no";
    };
  };

  # disable privileged ports
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.containers.enable = true;
  virtualisation.docker = {
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
  virtualisation.libvirtd = {
    enable = true;
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
