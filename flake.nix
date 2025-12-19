{
  description = "lav nixos config";

  inputs = {
    # nixpkgs (shallow copy, no history, we don't need it)
    stable.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-23.11";
    unstable.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-unstable";
    nixpkgs.follows = "unstable";
    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    # core
    hm.url = "github:nix-community/home-manager/release-23.11";
    hm.inputs.nixpkgs.follows = "nixpkgs";
    fup.url = "github:gytis-ivaskevicius/flake-utils-plus";

    # pkgs
    neovim.url = "github:nix-community/neovim-nightly-overlay";
    # pkgs.hyprland
    hyprland = {
      url = github:hyprwm/Hyprland?ref=v0.46.2;
      flake = false;
    };
    hypr-binds-flake = {
      url = github:hyprland-community/hypr-binds;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Fast nix search client
    nix-search = {
      url = github:diamondburned/nix-search;
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    { self
    , nixpkgs
    , hm
    , fup
    , ...
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
        neovim.overlay
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

      hostDefaults =
        let
          sys = "x86_64-linux";
        in
        {
          system = sys;
          modules = [ ];
          channelName = "unstable";
          specialArgs = { inherit inputs; system = sys; };
        };

      hosts = with inputs; {
        lavpc.modules = [
          "./hardware/lavpc.nix"
          "./systems/astral.nix"
          "./users/lav.nix"
        ];
        testvm.modules = [
          "./hardware/testvm.nix"
          "./systems/astral.nix"
          "./users/lav.nix"
        ];
      };

      nixosModules =
        let
          moduleList = [
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
