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
    (import ./_modules/cli)
    (import ./_modules/fish)
    (import ./_modules/gtk)
    (import ./_modules/audio)
    (import ./_modules/media)
    (import ./_modules/anyrun)
    (import ./_modules/ironbar)
    (import ./_modules/hyprland)
    (import ./_modules/niri)
    (import ./_modules/gnome)
    (import ./_modules/xdg-portals.nix)
    (import ./_modules/gaming)
    (import ./_modules/coding)
    (import ./_modules/codex)
    (import ./_modules/obs)
    (import ./_modules/ghostty)
    (import ./_modules/zen-browser)
    (import ./_modules/neovim)
    (import ./_modules/espanso)
    # (import ./_modules/yazi)
  ];
  module_imports = extract_imports modules;
in {
  imports =
    module_imports.nx
    ++ [
      ./_services/post_install
    ]
    ++ (with inputs; [
      nix-flatpak.nixosModules.nix-flatpak
      hm.nixosModules.home-manager
    ]);

  # environment.sessionVariables.NIXOS_OZONE_WL = "1";

  users.users.${cfg.username} = {
    hashedPasswordFile = config.sops.secrets.password_hash.path;

    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "libvirt"
      "input" # required for espanso
    ];
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
      jq
      bit-logo
      bagels
      vllm
      llama-cpp
      llama-swap
      python314Packages.huggingface-hub
      cursor-cli

      # dependencies
      rsync
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
