{
  pkgs,
  config,
  inputs,
  lib,
  system,
  ...
} @ args: let
  inherit (lib) mkIf mkMerge;
  inherit (import ../_lib/modules.nix) extract_imports;
  cfg = config.my_nix;

  modules = [
    (import ./modules/cli)
    (import ./modules/fish)
    (import ./modules/gtk)
    (import ./modules/audio)
    (import ./modules/media)
    (import ./modules/anyrun)
    (import ./modules/ironbar)
    (import ./modules/hyprland)
    (import ./modules/niri)
    (import ./modules/gnome)
    (import ./modules/xdg-portals.nix)
    (import ./modules/gaming)
    (import ./modules/coding)
    (import ./modules/codex)
    (import ./modules/obs)
    (import ./modules/ghostty)
    (import ./modules/zen-browser)
    (import ./modules/neovim)
    # (import ./modules/yazi)
  ];
  module_imports = extract_imports modules;
in {
  imports =
    module_imports.nx
    ++ (with inputs; [
      nix-flatpak.nixosModules.nix-flatpak
      hm.nixosModules.home-manager
    ]);

  # environment.sessionVariables.NIXOS_OZONE_WL = "1";

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

    ## cli tools
    ### nix
    ### gpg
    services = {
      syncthing = {
        enable = true;
      };
      gpg-agent = {
        enable = true;
        enableSshSupport = true;
      };
    };

    # etc
    home.packages = with pkgs; [
      # core
      libreoffice
      chromium

      # terminal
      ## emulator
      ghostty
      alacritty # backup
      ## multiplexer
      zellij
      ## tui
      systemctl-tui
      gdu # ncdu alternative (MUCH faster)

      # gui
      ## launcher
      fuzzel # backup
      ## file manager
      thunar
      ## settings
      nwg-look
      pwvucontrol

      # communication
      legcord

      ## programming
      mergiraf # git merge helper
      dbeaver-bin # db ide thing
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

      ## etc move later
      bit-logo
      bagels
      vllm
      llama-cpp
      llama-swap
      python314Packages.huggingface-hub

      # dependencies
      pinentry-curses
      bc
      perl
      runapp
      libnotify
      playerctl
      wl-clipboard # wl-paste/...
      cliphist
      xclip
      unzip
    ];
  };
}
