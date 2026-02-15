{self, ...} @ inputs: let
  DEFAULT_SYSTEM = "x86_64-linux";
  DEFAULT_CHANNEL = "unstable";

  DESKTOP_MODULES = [
    ../../systems/astral
    ../../users/lav.nix
  ];

  SERVER_MODULES = [
    ../../systems/tyrant
    ../../users/tyrant.nix
  ];

  MYLIB_PATH = ../../_lib;

  _m = obj: {attr ? "default"}: obj.nixosModules.${attr};

  # will assume hardware/<xxx> module matches <name>
  _h = name: modules: extra: {
    ${name} =
      {
        modules =
          [
            "${inputs.self}/hardware/${name}"
          ]
          ++ modules;
        specialArgs.mylib = import MYLIB_PATH (let
          pkgs = import inputs.nixpkgs {
            system = DEFAULT_SYSTEM; # TODO: ^0 change later
          };
        in {
          inherit inputs;
          inherit pkgs;
          inherit (pkgs) lib;
          inherit (self.nixosConfigurations.${name}) config;
        });
      }
      // extra;
  };
in {
  hostDefaults = {
    system = DEFAULT_SYSTEM;
    channelName = DEFAULT_CHANNEL;

    # for module imports
    specialArgs = {
      inherit inputs;
      system = DEFAULT_SYSTEM;
    };
    #
    # shared modules
    modules = with inputs; [
      (_m disko {})
      (_m sops-nix {attr = "sops";})
      ../../_modules/options.nix
      ../../_modules/secrets.nix
      ../../hardware/_modules/grub.nix
      ../../systems/_modules/home-manager.nix
      ../../systems/_modules/nix.nix
      ../../systems/_modules/lix.nix
    ];
  };

  hosts =
    ## desktops
    _h "lavpc" (DESKTOP_MODULES
      ++ [
        ../../systems/_modules/services/ollama.nix
      ]) {}
    // (_h "testvm" DESKTOP_MODULES {})
    ## servers
    // (_h "tyrant" SERVER_MODULES {})
    // (_h "testservervm" SERVER_MODULES {})
    ## other / special
    // (_h "iso" [../../systems/iso] {});
}
