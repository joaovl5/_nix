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
  users.groups.podman = {
    name = "podman";
  };

  virtualisation.podman = {
    enable = true;
    # simulate a docker socket
    dockerSocket.enable = true;
    # create a `docker` alias for podman, to use it as a drop-in replacement
    dockerCompat = true;
    # required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  virtualisation.containers.storage.settings = {
    storage = {
      driver = "btrfs";
      runroot = "/run/containers/storage";
      graphroot = "/var/lib/containers/storage";
      options.overlay.mountopt = "nodev,metacopy=on";
    };
  };
  virtualisation.oci-containers.backend = lib.mkForce "podman";
  networking.firewall.enable = false;

  environment.systemPackages = with pkgs; [
    # virtualisation
    podman
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
