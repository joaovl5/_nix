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
    hashedPasswordFile = config.sops.secrets.password_hash.path;
    shell = pkgs.bash;
  };

  # terminal shell
  programs.fish.enable = true;

  # xwayland
  programs.xwayland.enable = true;

  # scans network, detects hostnames
  services.avahi.enable = true;
  # automount media devices (cameras, phones, etc)
  services.gvfs.enable = true;
  # auth backend
  security.polkit.enable = true;
  # ssh daemon and agent
  services.openssh.enable = true;
  programs.ssh.startAgent = true;
  services.flatpak.enable = true;
  programs.dconf.enable = true;
  services.xserver.enable = false;
  services.dbus.enable = true;
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
    ## components
    ### bar
    ironbar
    ## file manager
    thunar
    ## terminal
    ghostty
    kitty
    ## audio
    openal
    pulseaudio
    ## gui settings
    nwg-look
    pwvucontrol

    # utils
    neovim # text editing
    ## terminal
    starship # shell prompt
    tmux # terminal multiplexer
    sops # secrets thing
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

  system.stateVersion = "26.05";
}
