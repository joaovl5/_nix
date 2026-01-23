{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.my_nix;
in {
  imports = [
    ../_modules/console
    ../_modules/security
    ../_modules/services/login.nix
    ../_modules/services/pipewire.nix
    ../_modules/services/ntp.nix
  ];

  networking = {
    hostName = lib.mkForce cfg.hostname;
  };

  users.mutableUsers = false;
  users.users.root = {
    hashedPasswordFile = config.sops.secrets.password_hash.path;
    shell = pkgs.bash;
  };

  # Services
  services.avahi.enable = true; # scans network, detects hostnames
  services.gvfs.enable = true; # automount media devices
  services.openssh.enable = true;
  services.flatpak.enable = true;
  services.xserver.enable = false;
  services.dbus.enable = true;
  services.dbus.implementation = lib.mkForce "dbus";
  services.dbus.packages = with pkgs; [dconf];

  # Programs
  programs.fish.enable = true; # shell
  programs.xwayland.enable = true; # x11 compat
  programs.ssh.startAgent = true;
  programs.dconf.enable = true; # dependency

  # Virtualisation Support
  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.containers.enable = true;
  virtualisation.libvirtd.enable = true;
  # rootless docker setup
  virtualisation.docker = {
    enable = false;
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

  documentation.man.generateCaches = true;

  environment.systemPackages = with pkgs; [
    # virtualisation
    ## containers
    docker
    docker-compose

    # utils
    neovim # text editing
    ## terminal
    starship # shell prompt
    tmux # terminal multiplexer
    sops # secrets tool
    ### nix
    nh # better cli
    nix-prefetch-scripts
    ### git
    git
    lazygit
    ### coreutils alternatives
    zoxide # fast cd jumps
    eza # ls alt.
    bat # cat alt.
    rm-improved # rm alt.
    ripgrep # grep alt.
    ### system monitoring/inspection
    pciutils
    btop
    ### etc
    tealdeer # tldr alternative
    pandoc
    wget
    curl
    dconf
    gcc
    gnumake
    lldb
    lshw
  ];

  system.stateVersion = "25.11";
}
