{
  description = "lav nixos config";

  inputs = {
    # ---------------
    # nixpkgs
    # ---------------
    stable.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-25.11&shallow=1";
    unstable.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-unstable&shallow=1";
    nixpkgs.follows = "unstable";
    nur = {
      url = "git+https://github.com/nix-community/NUR?shallow=1";
      inputs.nixpkgs.follows = "unstable";
    };
    # ---------------
    # core
    # ---------------
    ## home manager
    hm = {
      url = "git+https://github.com/nix-community/home-manager?shallow=1";
      inputs.nixpkgs.follows = "unstable";
    };
    ## flake utils lib
    fup.url = "git+https://github.com/gytis-ivaskevicius/flake-utils-plus?shallow=1";
    ## disko
    disko = {
      url = "git+https://github.com/nix-community/disko?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## deployment
    deploy-rs.url = "git+https://github.com/serokell/deploy-rs?shallow=1";
    ## secrets management
    sops-nix = {
      url = "git+https://github.com/Mic92/sops-nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## private secrets repository
    mysecrets = {
      url = "git+ssh://git@github.com/joaovl5/__secrets.git?ref=main&shallow=1";
      flake = false;
    };

    # ---------------
    # pkgs
    # ---------------
    ## neovim
    neovim.url = "git+https://github.com/nix-community/neovim-nightly-overlay?shallow=1";
    ## hyprland
    hyprland-plugins = {
      url = "git+https://github.com/hyprwm/hyprland-plugins?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
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
    disko,
    sops-nix,
    deploy-rs,
    fup,
    ...
  } @ inputs:
    fup.lib.mkFlake (import ./outputs inputs)
    // fup.lib.mkFlake {
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
        self.overlays.default
        nur.overlays.default
        deploy-rs.overlays.default
        # neovim.overlays.default
        niri.overlays.niri
        fenix.overlays.default
      ];

      ## fine-tuning channel cfg
      channels = {
        stable.input = inputs.stable;
        unstable = {
          input = inputs.unstable;
          # overlaysBuilder = channels: [
          #   (final: prev: {
          #     # inherit
          #     #   (channels.stable)
          #     #   pipewire
          #     #   ;
          #   })
          # ];
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
          ./hardware/lavpc
          ./systems/astral
          ./systems/_modules/services/ollama.nix
          ./users/lav.nix
        ];
        testvm.modules = [
          ./hardware/testvm
          ./systems/astral
          ./users/lav.nix
        ];

        ### servers
        tyrant.modules = [
          ./hardware/tyrant
          ./systems/tyrant
          ./users/tyrant.nix
        ];

        testservervm.modules = [
          ./hardware/testservervm
          ./systems/tyrant
          ./users/tyrant.nix
        ];

        ### other/special
        iso.modules = [
          ./systems/iso
        ];
      };

      # ---------------
      # Build
      # ---------------
      packages.x86_64-linux.build_iso =
        self.nixosConfigurations.iso.config.system.build.isoImage;

      # ---------------
      # Deployment
      # ---------------
      deploy = let
        mk_deploy = {
          host_system,
          ssh_user ? "root",
          user ? "root",
        }: {
          inherit user;
          sshUser = ssh_user;
          path =
            deploy-rs.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations.${host_system};
        };
        mk_node = {
          host_system,
          hostname ? host_system,
          ssh_user ? "root",
          user ? "root",
        }: {
          ${host_system} = {
            inherit hostname;
            profiles.system = mk_deploy {inherit host_system ssh_user user;};
          };
        };
      in {
        # sshUser = "root";
        # sudo = "run0";
        remoteBuild = false;
        sudo = "run0 --user";

        nodes =
          # (mk_node {host_system = "tyrant";}) //
          mk_node {
            host_system = "testservervm";
            hostname = "192.168.122.169";
            ssh_user = "tyrant";
            user = "root";
          };
      };

      # ---------------
      # Checks
      # ---------------
      checks =
        builtins.mapAttrs
        (_system: deployLib: deployLib.deployChecks self.deploy)
        deploy-rs.lib;

      # ---------------
      # Other settings
      # ---------------
      overlays.default = import ./overlays;
    };
}
