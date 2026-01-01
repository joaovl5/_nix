{
  pkgs,
  config,
  inputs,
  lib,
  system,
  ...
}: let
  cfg = config.my_nix;
in {
  imports = with inputs; [
    hm.nixosModules.home-manager
    ./services/technitium-dns
  ];

  environment.shells = [pkgs.fish];
  programs.fish.enable = true;

  users.users.${cfg.username} = {
    hashedPasswordFile = config.sops.secrets.password_hash.path;
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = ["wheel" "libvirt"];
  };

  home-manager.users.${cfg.username} = {...}: {
    home.stateVersion = "23.11";

    imports = [
      ./hm/modules/hyprland
    ];

    programs.git = {
      enable = true;
      settings = {
        user.email = cfg.email;
        user.name = cfg.name;
      };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
    };

    gtk = {
      enable = true;

      # inherit font;
      iconTheme = {
        package = pkgs.papirus-icon-theme;
        name = "ePapirus";
      };
      theme = {
        package = pkgs.nordic;
        name = "Nordic";
      };
    };

    home.packages = with pkgs; [
      # deps
      pinentry-curses

      # core
      libreoffice
      obs-studio
      ghostty

      ## launcher
      anyrun
      ## file manager
      thunar
      ## terminal
      ghostty
      kitty
      tmux
      ## clipboard manager
      wl-clipboard # wl-paste/...
      cliphist

      ## games/emulation/vms
      steam
      steam-run
      ckan
      glfw
      wineWowPackages.full
      winetricks
      virt-manager

      ## utils
      ripgrep
      gcc
      gnumake
      lldb
      lshw
      nix-prefetch-git
      pandoc
      pciutils
      (with fenix;
        combine [
          default.toolchain
          latest.rust-src
        ])
      xclip
    ];
  };
}
