{
  description = "lav nixos config";

  inputs = {
    # ---------------
    # nixpkgs
    # ---------------
    stable.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-25.11&shallow=1";
    unstable.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-unstable&shallow=1";
    nixpkgs.follows = "unstable";
    nur.url = "git+https://github.com/nix-community/NUR?shallow=1";
    nur.inputs.nixpkgs.follows = "unstable";

    # ---------------
    # core
    # ---------------
    ## home manager
    hm.url = "git+https://github.com/nix-community/home-manager?shallow=1";
    hm.inputs.nixpkgs.follows = "unstable";
    ## flake utils lib
    fup.url = "git+https://github.com/gytis-ivaskevicius/flake-utils-plus?shallow=1";
    ## disko
    disko.url = "git+https://github.com/nix-community/disko?shallow=1";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    ## secrets management
    sops-nix.url = "git+https://github.com/Mic92/sops-nix?shallow=1";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    ## private secrets repository
    mysecrets.url = "git+ssh://git@github.com/joaovl5/__secrets.git?ref=main&shallow=1";
    mysecrets.flake = false;

    # ---------------
    # pkgs
    # ---------------
    ## neovim
    neovim.url = "git+https://github.com/nix-community/neovim-nightly-overlay?shallow=1";
    ## hyprland
    # hyprland = {
    #   url = "github:hyprwm/Hyprland?";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    hyprland-plugins = {
      url = "git+https://github.com/hyprwm/hyprland-plugins?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs.hyprland.follows = "hyprland";
    };
    ## niri
    niri = {
      url = "git+https://github.com/sodiboo/niri-flake?shallow=1";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs";
      };
    };
    ## zen browser
    zen-browser = {
      url = "git+https://github.com/0xc000022070/zen-browser-flake?shallow=1";
      inputs.nixpkgs.follows = "unstable";
      inputs.home-manager.follows = "hm";
    };
    firefox-addons = {
      ## support for declarative extensions
      url = "git+https://gitlab.com/rycee/nur-expressions?dir=pkgs/firefox-addons&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## rust nightly support
    fenix = {
      url = "git+https://github.com/nix-community/fenix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## flatpak support
    nix-flatpak.url = "git+https://github.com/gmodena/nix-flatpak/?ref=v0.6.0&shallow=1";
  };

  outputs = {
    self,
    nixpkgs,
    disko,
    sops-nix,
    hm,
    fup,
    ...
  } @ inputs:
    fup.lib.mkFlake {
      inherit self inputs; # required

      ## supported systems
      supportedSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      # ---------------
      # Channels
      # ---------------

      channelsConfig.allowUnfree = true;

      ## these overlays get applied on *all* channels
      sharedOverlays = with inputs; [
        self.overlay
        nur.overlays.default
        # neovim.overlays.default
        niri.overlays.niri
        fenix.overlays.default
      ];

      ## fine-tuning channel cfg
      channels = {
        stable.input = inputs.stable;
        unstable = {
          input = inputs.unstable;
          overlaysBuilder = channels: [
            (final: prev: {
              # inherit
              #   (channels.stable)
              #   pipewire
              #   ;
            })
          ];
        };
      };

      # ---------------
      # Hosts
      # ---------------

      hostDefaults = let
        default_system = "x86_64-linux";
      in {
        # default sys architecture
        system = default_system;
        # default channel
        channelName = "unstable";
        # args for module imports
        specialArgs = {
          inherit inputs;
          system = default_system;
        };
        # modules for all hosts
        modules = [
          disko.nixosModules.default
          sops-nix.nixosModules.sops
          ./_modules/options.nix
          ./_modules/secrets.nix
          ./hardware/_modules/grub.nix
          ./systems/_modules/home-manager.nix
          ./systems/_modules/nix.nix
          ./systems/_modules/lix.nix
        ];
      };

      ## host-specific config
      hosts = {
        ### desktops
        lavpc.modules = [
          ./hardware/lavpc.nix
          ./systems/astral
          ./systems/_modules/services/ollama.nix
          ./users/lav.nix
        ];
        testvm.modules = [
          ./hardware/testvm.nix
          ./systems/astral
          ./users/lav.nix
        ];

        ### servers
        tyrant.modules = [
          ./hardware/tyrant.nix
          ./systems/tyrant
          ./users/tyrant.nix
        ];

        ### other/special
        # iso.modules = [
        #   ./modules/iso.nix
        # ];
      };

      # ---------------
      # Build
      # ---------------
      packages.x86_64-linux.build_iso =
        self.nixosConfigurations.iso.config.system.build.isoImage;

      # ---------------
      # Other settings
      # ---------------
      overlay = import ./overlays;
    };
}
