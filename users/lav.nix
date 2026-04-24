{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  inherit (import ../_lib/modules) extract_imports;
  cfg = config.my.nix;
  local_packages = import ../packages {inherit pkgs inputs;};

  modules = [
    (import ./_modules/cli)
    (import ./_modules/yazi)
    (import ./_modules/fish)
    (import ./_modules/nushell)
    (import ./_modules/starship)
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
    (import ./_modules/ai)
    (import ./_modules/obs)
    (import ./_modules/term)
    (import ./_modules/browsing)
    (import ./_modules/neovim)
    (import ./_modules/emacs)
    (import ./_modules/espanso)
    (import ./_modules/kanata)
    (import ./_modules/discord)
    (import ./_modules/syncthing)
    (import ./_modules/storage)
  ];
  module_imports = extract_imports modules;

  # required for consuming in optnix
  computed_hm_imports =
    [
      inputs.nur.modules.homeManager.default
    ]
    ++ module_imports.hm;
in {
  imports =
    module_imports.nx
    ++ [
      ./_services/post_install
      ./_units
    ]
    ++ (with inputs; [
      nix-flatpak.nixosModules.nix-flatpak
      hm.nixosModules.home-manager
      nur.modules.nixos.default
    ]);

  options.hm_modules = lib.mkOption {
    description = "Home-manager modules for Optnix";
    default = computed_hm_imports;
  };

  config = {
    users.groups.uinput = {};
    users.users.${cfg.username} = {
      # hashedPasswordFile = s.secret_path "password_hash";

      isNormalUser = true;
      shell = pkgs.fish;
      extraGroups = [
        "wheel"
        "libvirt"
        "input"
      ];
    };

    home-manager.users.${cfg.username} = let
      inherit (config) hm_modules;
    in
      _: {
        imports = hm_modules ++ [../home/_modules/hybrid-links];

        hybrid-links.flake_root = inputs.self.outPath;
        hybrid-links.flake_path = cfg.flake_location;

        home.stateVersion = "23.11";

        ## cli tools
        my.syncthing = {
          enable = true;
        };

        ### gpg
        services = {
          gpg-agent = {
            enable = true;
            enableSshSupport = true;
          };
        };

        # etc
        home.packages = with pkgs; [
          # terminal
          ## emulator
          ghostty
          alacritty # backup
          ## multiplexer
          ## tui
          systemctl-tui
          gdu # ncdu alternative (MUCH faster on SSDs)

          # gui
          waylock ## locker
          ## launcher
          fuzzel # backup
          ## docs
          libreoffice
          ## file manager
          thunar
          ## settings
          nwg-look
          pwvucontrol

          ## programming
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
          zrythm
          ardour
          wireguard-tools
          copier
          jq
          bit-logo
          python314Packages.huggingface-hub
          cursor-cli
          azure-cli
          (openvpn.override {
            openssl = openssl_legacy;
          })
          rustdesk

          # dependencies
          rsync
          go-grip
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
          local_packages.frag
        ];
      };
  };
}
