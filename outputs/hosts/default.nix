inputs: let
  DEFAULT_SYSTEM = "x86_64-linux";
  DEFAULT_CHANNEL = "unstable";

  _m = obj: {attr ? "default"}: obj.nixosModules.${attr};

  # assumes hardware/<name> module matches <name>
  _h = name: modules: extra: {
    ${name} =
      {
        modules =
          [
            "${inputs.self}/hardware/${name}"
          ]
          ++ modules;
        specialArgs.mylib = import ../../_lib (let
          pkgs = import inputs.nixpkgs {
            system = DEFAULT_SYSTEM;
          };
        in {
          inherit inputs;
          inherit pkgs;
          inherit (pkgs) lib;
        });
      }
      // extra;
  };

  SHARED_MODULES = with inputs; [
    (_m disko {})
    (_m sops-nix {attr = "sops";})
    (_m nixos-dns {attr = "dns";})
    (_m hm {attr = "home-manager";})
    ../../_modules/options.nix
    ../../_modules/secrets.nix
    ../../hardware/_modules/grub.nix
    ../../systems/_modules/home-manager.nix
    ../../systems/_modules/nix.nix
    ../../systems/_modules/lix.nix
    ../../systems/_modules/shell
    ../../systems/_modules/dns
    ../../users/_units
  ];
in {
  # is consumed for kexec tarball script
  inherit SHARED_MODULES;

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
    modules = SHARED_MODULES;
  };

  hosts =
    ## desktops
    _h "lavpc" [
      ../../systems/astral
      ../../users/lav.nix
      ../../systems/_modules/services/ollama.nix
    ] {}
    ## servers
    // (_h "tyrant" [../../systems/tyrant] {})
    // (_h "temperance" [../../systems/temperance] {})
    ## other / special
    // (_h "iso" [../../systems/iso] {});
}
