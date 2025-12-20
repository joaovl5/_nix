{
  description = "lav nixos config";

  inputs = {
    # nixpkgs (shallow copy, no history, we don't need it)
    stable.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-23.11";
    unstable.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-unstable";
    nixpkgs.follows = "unstable";
    nur.url = "github:nix-community/NUR?shallow=1";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    # core
    hm.url = "git+https://github.com/nix-community/home-manager?shallow=1&ref=master";
    hm.inputs.nixpkgs.follows = "nixpkgs";
    fup.url = "github:gytis-ivaskevicius/flake-utils-plus?shallow=1";
    disko.url = "github:nix-community/disko?shallow=1?shallow=1";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # pkgs
    neovim.url = "github:nix-community/neovim-nightly-overlay?shallow=1";
    # hyprland
    hyprland = {
      url = "github:hyprwm/Hyprland?ref=v0.46.2&shallow=1";
      flake = false;
    };
    hypr-binds-flake = {
      url = "github:hyprland-community/hypr-binds?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # zen
    zen-browser = {
      url = "github:youwen5/zen-browser-flake?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Fast nix search client
    nix-search = {
      url = "github:diamondburned/nix-search?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # better rust nightly support
    fenix = {
      url = "github:nix-community/fenix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    hm,
    fup,
    ...
  } @ inputs:
    fup.lib.mkFlake {
      inherit self inputs;
      supportedSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      # overlays that get applied to all channels
      sharedOverlays = with inputs; [
        self.overlay
        nur.overlays.default
        neovim.overlays.default
        fenix.overlays.default
      ];

      channels = {
        stable.input = inputs.stable;
        unstable = {
          input = inputs.unstable;
          overlaysBuilder = channels: [
            (final: prev: {
              inherit (channels) stable;
              # inherit (channels.stable) pass-secret-service;
            })
          ];
        };
      };

      channelsConfig.allowUnfree = true;

      hostDefaults = let
        sys = "x86_64-linux";
      in {
        system = sys;
        modules = [];
        channelName = "unstable";
        specialArgs = {
          inherit inputs;
          system = sys;
        };
      };

      hosts = with inputs; {
        lavpc.modules = [
          disko.nixosModules.default
          ./hardware/lavpc.nix
          ./hardware/modules/pipewire.nix
          ./hardware/modules/grub.nix
          ./systems/astral.nix
          ./systems/modules/home-manager.nix
          ./users/lav.nix
        ];
        testvm.modules = [
          inputs.disko.nixosModules.default
          ./hardware/testvm.nix
          ./hardware/modules/pipewire.nix
          ./hardware/modules/grub.nix
          ./systems/astral.nix
          ./systems/modules/home-manager.nix
          ./users/lav.nix
        ];
      };

      nixosModules = let
        moduleList = [
          inputs.disko.nixosModules.default
          ./systems/modules/nix.nix
          ./systems/modules/home-manager.nix
          ./hardware/modules/pipewire.nix
          ./hardware/modules/grub.nix
        ];
      in
        fup.lib.exportModules moduleList;

      overlay = import ./pkgs;
    };
}
