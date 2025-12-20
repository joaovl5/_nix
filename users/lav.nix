{
  pkgs,
  inputs,
  lib,
  system,
  ...
}: let
  # font = {
  #   name = "FiraCode Nerd Font";
  #   package = pkgs.nerd-fonts.override { fonts = [ "FiraCode" ]; };
  #   size = 13;
  # };
  term = "ghostty";
  browser = "zen-browser";
  editor = "nvim";
in {
  imports = with inputs; [
    hm.nixosModules.home-manager
  ];

  environment.shells = [pkgs.fish];
  programs.fish.enable = true;

  users.users.lav = {
    initialPassword = "12";
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = ["wheel" "docker" "libvirt"];
  };

  home-manager.users.lav = {config, ...}: {
    home.stateVersion = "23.11";

    programs.git = {
      enable = true;
      settings.userEmail = "vieiraleao2005@gmail.com";
      settings.userName = "João Pedro";
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
      # pinentryFlavor = pkgs.pinentry-curses;
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
