{
  pkgs,
  config,
  inputs,
  lib,
  system,
  ...
} @ args: let
  inherit (lib) mkIf mkMerge;
  inherit (import ../lib/modules.nix) extract_imports;
  cfg = config.my_nix;

  modules = [
    (import ./modules/cli)
    (import ./modules/fish)
    (import ./modules/zen-browser)
    (import ./modules/ghostty)
    (import ./modules/anyrun)
    (import ./modules/ironbar)
    (import ./modules/coding)
    (import ./modules/gtk)
    (import ./modules/gnome)
    (import ./modules/hyprland)
    (import ./modules/niri)
    (import ./modules/gaming)
    (import ./modules/codex)
  ];
  module_imports = extract_imports modules;
in {
  imports =
    module_imports.nx
    ++ (with inputs; [
      nix-flatpak.nixosModules.nix-flatpak
      hm.nixosModules.home-manager
    ]);

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # programs.nix-ld = {
  #   enable = true;
  #   libraries = with pkgs; [
  #   ];
  # };
  # gui
  xdg.terminal-exec = {
    enable = true;
    package = pkgs.xdg-terminal-exec-mkhl;
    settings = let
      terms = [
        "com.mitchellh.ghostty.desktop"
        "kitty.desktop"
      ];
    in {
      default = terms;
    };
  };

  users.users.${cfg.username} = {
    hashedPasswordFile = config.sops.secrets.password_hash.path;

    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = ["wheel" "libvirt"];
  };

  home-manager.users.${cfg.username} = {config, ...}: {
    imports =
      module_imports.hm
      ++ [
      ];

    home.stateVersion = "23.11";

    # # set dpi for 4k monitor
    # xresources.properties = {
    #   # dpi for Xorg's font
    #   "Xft.dpi" = 150;
    #   # or set a generic dpi
    #   "*.dpi" = 150;
    # };

    # gaming

    # gtk's theme settings, generate files:
    #   1. ~/.gtkrc-2.0
    #   2. ~/.config/gtk-3.0/settings.ini
    #   3. ~/.config/gtk-4.0/settings.ini

    ## cli tools
    ### nix
    ## services
    ### gpg
    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
    };

    # etc
    home.packages = with pkgs; [
      # deps
      pinentry-curses
      bc
      runapp
      perl

      # core
      libreoffice
      obs-studio

      # gui
      ## notifications
      libnotify
      ## terminal
      zellij
      ## audio
      playerctl
      ## clipboard manager
      wl-clipboard # wl-paste/...
      cliphist
      xclip

      # communication
      legcord

      ## programming
      mergiraf # git merge helper
      ### rust
      (with fenix;
        combine [
          default.toolchain
          latest.rust-src
        ])
      ### js :(
      nodejs

      ## vms
      virt-manager
    ];
  };
}
