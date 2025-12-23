{
  pkgs,
  lib,
  inputs,
  ...
}: let
  secrets = {
    hostName = "astral";
  };
in {
  networking = {
    hostName = lib.mkForce secrets.hostName;
  };

  users.mutableUsers = false;
  users.users.root = {
    initialPassword = "12";
    shell = pkgs.bash;
  };

  # scans network, detects hostnames
  services.avahi.enable = true;
  # ssh daemon and agent
  services.openssh.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  virtualisation.libvirtd = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    dconf
    curl
    git
    htop
    openal
    wget
  ];

  system.stateVersion = "26.05";
}
