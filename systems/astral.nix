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
  # automount media devices (cameras, phones, etc)
  services.gvfs.enable = true;
  # auth backend
  security.polkit.enable = true;
  # ssh daemon and agent
  services.openssh.enable = true;
  programs.ssh.startAgent = true;
  services.dbus.packages = with pkgs; [dconf];

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

  documentation.man.generateCaches = true;

  environment.systemPackages = with pkgs; [
    # virtualisation
    ## containers
    docker
    docker-compose

    # gui
    ## browser
    inputs.zen-browser.packages.${pkgs.system}.default
    ## audio
    openal
    pulseaudio

    # utils
    neovim # text editing
    ## terminal
    fish # shell
    tmux # terminal multiplexer
    btop # resource monitor
    ### git
    git
    ### etc
    wget
    curl
    dconf
  ];

  system.stateVersion = "26.05";
}
