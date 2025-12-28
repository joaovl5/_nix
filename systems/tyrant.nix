{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.my_nix;
in {
  networking = {
    hostName = lib.mkForce cfg.hostname;
  };

  users.mutableUsers = false;
  users.users.root = {
    initialPassword = "12";
    shell = pkgs.bash;
  };

  # scans network, detects hostnames
  services.avahi.enable = true;
  # ssh daemon and agent
  services.openssh = {
    enable = true;

    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true; # todo remove later
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

  system.stateVersion = "26.05";
}
