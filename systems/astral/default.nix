{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.my.nix;
in {
  imports = [
    ../_modules/security
    ../_modules/services/login.nix
    ../_modules/services/pipewire.nix
    ../_modules/services/ntp.nix
    ../_modules/console
    ../_modules/shell
    {my_system.title = lib.readFile ./assets/title.txt;}
  ];

  networking = {
    hostName = lib.mkForce cfg.hostname;
  };

  users.mutableUsers = false;
  users.users.root = {
    hashedPassword = lib.mkForce null;
    hashedPasswordFile = config.sops.secrets.password_hash.path;
    shell = pkgs.bash;
  };

  # zram
  zramSwap.enable = true;
  boot.tmp.useZram = true;

  # Services
  services = {
    avahi.enable = true; # scans network, detects hostnames
    gvfs.enable = true; # automount media devices
    openssh.enable = true;
    flatpak.enable = true;
    xserver.enable = false;
    dbus = {
      enable = true;
      implementation = lib.mkForce "dbus";
      packages = with pkgs; [dconf];
    };
  };

  # Programs
  programs = {
    fish.enable = true; # shell
    xwayland.enable = true; # x11 compat
    ssh.startAgent = true;
    dconf.enable = true; # dependency
  };

  # Virtualisation Support
  virtualisation = {
    spiceUSBRedirection.enable = true;
    containers.enable = true;
    libvirtd.enable = true;

    # rootless docker setup
    docker = {
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
  };

  # install documentation pages
  documentation = {
    enable = true;
    nixos = {
      enable = true;
      includeAllModules = true;
    };
    doc = {enable = true;};
    dev = {enable = true;};
    man = {
      enable = true;
      generateCaches = true;
    };
  };

  environment = {
    enableAllTerminfo = true;
    systemPackages = with pkgs; [
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
  };

  system.stateVersion = "25.11";
}
