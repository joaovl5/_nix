{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  secrets = {
    hostName = "tyrant";
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
  services.openssh = {
    enable = true;

    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true; # todo remove later
    };
  };

  virtualisation.podman = {
    enable = true;
    # dockerCompat = true;
    dockerSocket.enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
    defaultNetwork.settings = {
      "dns_enabled" = false; # don't use port 53 - pi-hole conflicts
    };
  };
  virtualisation.oci-containers.backend = lib.mkForce "podman";
  # Enable container name DNS for all Podman networks.
  networking.firewall.interfaces = let
    matchAll =
      if !config.networking.nftables.enable
      then "podman+"
      else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [53];
  };

  environment.systemPackages = with pkgs; [
    # virtualisation
    podman-compose

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
