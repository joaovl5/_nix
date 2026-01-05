{
  description = "lav nixos config";

  inputs = {
    # ---------------
    # nixpkgs
    # ---------------
    stable.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-23.11";
    unstable.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-unstable";
    nixpkgs.follows = "unstable";
    nur.url = "github:nix-community/NUR?shallow=1";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    # ---------------
    # core
    # ---------------
    ## home manager
    hm.url = "git+https://github.com/nix-community/home-manager?shallow=1&ref=master";
    hm.inputs.nixpkgs.follows = "nixpkgs";
    ## flake utils lib
    fup.url = "github:gytis-ivaskevicius/flake-utils-plus?shallow=1";
    ## disko
    disko.url = "github:nix-community/disko?shallow=1?shallow=1";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    ## secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    ## private secrets repository
    mysecrets.url = "git+ssh://git@github.com/joaovl5/__secrets.git?shallow=1";
    mysecrets.flake = false;

    # ---------------
    # pkgs
    # ---------------
    ## neovim
    neovim.url = "github:nix-community/neovim-nightly-overlay?shallow=1";
    ## hyprland
    hyprland = {
      url = "github:hyprwm/Hyprland?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins?shallow=1";
      inputs.hyprland.follows = "hyprland";
    };
    ## zen browser
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "hm";
    };
    firefox-addons = {
      ## support for declarative extensions
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## rust nightly support
    fenix = {
      url = "github:nix-community/fenix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## flatpak support
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.6.0&shallow=1";
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
        neovim.overlays.default
        fenix.overlays.default
      ];

      ## fine-tuning channel cfg
      channels = {
        stable.input = inputs.stable;
        unstable = {
          input = inputs.unstable;
          overlaysBuilder = channels: [
            (final: prev: {
              # we can override packages from stable here
              # inherit (channels.stable) pass-secret-service;
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
          ./modules/options.nix
          ./modules/secrets.nix
          ./hardware/modules/grub.nix
          ./systems/modules/systemd.nix
          ./systems/modules/home-manager.nix
          ./systems/modules/nix.nix
        ];
      };

      ## host-specific config
      hosts = {
        ### desktops
        lavpc.modules = [
          ./hardware/lavpc.nix
          ./hardware/modules/pipewire.nix
          ./systems/astral.nix
          ./systems/modules/display-manager.nix
          ./users/lav.nix
        ];
        testvm.modules = [
          ./hardware/testvm.nix
          ./hardware/modules/pipewire.nix
          ./systems/astral.nix
          ./systems/modules/display-manager.nix
          ./users/lav.nix
        ];

        ### servers
        tyrant.modules = [
          ./hardware/tyrant.nix
          ./systems/tyrant.nix
          ./users/tyrant.nix
        ];

        ### other/special
        iso.modules = [
          ./modules/iso.nix
        ];
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
