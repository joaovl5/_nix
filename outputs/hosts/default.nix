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
        specialArgs = inputs.self._utils.hosts.mk_extra_args {
          pkgs = import inputs.nixpkgs {system = DEFAULT_SYSTEM;};
        };
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
    ../../_modules/vm.nix
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
  _utils.hosts.shared_modules = SHARED_MODULES;
  _utils.hosts.mk_extra_args = {pkgs, ...}: {
    mylib = import ../../_lib {
      inherit
        inputs
        pkgs
        ;
      inherit (pkgs) lib;
    };
    inherit inputs;
    system = DEFAULT_SYSTEM;
  };

  hostDefaults = {
    system = DEFAULT_SYSTEM;
    channelName = DEFAULT_CHANNEL;

    # shared modules
    modules = SHARED_MODULES;
  };

  hosts =
    ## desktops
    _h "lavpc" [
      ../../systems/astral
      ../../users/lav.nix
      ../../systems/_modules/services/ollama.nix
    ] {channelName = "unstable-small";}
    ## servers
    // (_h "tyrant" [../../systems/tyrant] {})
    // (_h "temperance" [../../systems/temperance] {})
    ## other / special
    // (_h "iso" [../../systems/iso] {});
}
