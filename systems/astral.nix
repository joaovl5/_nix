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
  # automount media devices (cameras, phones, etc)
  services.gvfs.enable = true;
  # auth backend
  security.polkit.enable = true;
  # ssh daemon and agent
  services.openssh.enable = true;
  programs.ssh.startAgent = true;
  services.dbus.packages = with pkgs; [dconf];

  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.containers.enable = true;
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
  users.groups.podman = {
    name = "podman";
  };
  # virtualisation.docker = {
  #   enable = true;
  #   autoPrune = {
  #     enable = true;
  #     dates = "weekly";
  #   };
  # };
  virtualisation.libvirtd = {
    enable = true;
  };

  documentation.man.generateCaches = true;

  environment.systemPackages = with pkgs; [
    # virtualisation
    podman
    podman-compose
    # utils
    dconf
    curl
    git
    htop
    openal
    neovim
    pulseaudio
    wget
    fish
    inputs.zen-browser.packages.${pkgs.system}.default
  ];

  system.stateVersion = "26.05";
}
