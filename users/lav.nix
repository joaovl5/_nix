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
    (import ./modules/hyprland)
    (import ./modules/gnome)
    (import ./modules/gtk)
    (import ./modules/coding)
    (import ./modules/gaming)
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

  services.flatpak.enable = true;
  services.flatpak.packages = [
    "com.stremio.Stremio" # nixpkgs stremio is currently broken
  ];

  environment.shells = [pkgs.fish];
  programs.fish.enable = true;

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
      ++ (with inputs; [
        ./modules/hm/zen-browser
      ]);

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
    ### git
    programs.git = {
      enable = true;
      settings = {
        user.email = cfg.email;
        user.name = cfg.name;
      };
    };

    ### nix
    programs.nh = mkMerge [
      {
        enable = true;
        clean.enable = true;
        clean.extraArgs = "--keep 5 --keep-since 5d";
      }
      (mkIf (cfg.flake_location != null) {
        flake = cfg.flake_location;
      })
    ];

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
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

      # core
      libreoffice
      obs-studio
      ghostty
      kitty

      # gui
      ## notifications
      libnotify
      ## launcher
      anyrun
      ## terminal
      zellij
      ## audio
      playerctl
      ## clipboard manager
      wl-clipboard # wl-paste/...
      cliphist
      xclip

      # communication
      goofcord

      ## programming
      alejandra # formatter
      nixd # lsp
      nil # lsp
      ### perl (required for some dependencies apparently)
      perl
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
