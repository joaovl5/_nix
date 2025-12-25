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

  # disable privileged ports
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
  virtualisation.podman = {
    enable = true;
    # dockerCompat = true;
    dockerSocket.enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
    # required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;
  };
  virtualisation.oci-containers.backend = lib.mkForce "podman";

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
