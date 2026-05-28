{
  den,
  globals,
  inputs,
  self,
  ...
}: {
  den.default = {
    includes = [
      den.aspects.provider-disko
      den.aspects.provider-sops
      den.aspects.provider-nixos-dns
      den.aspects.base-options
      den.aspects.base-secrets
      den.aspects.base-vm
      den.aspects.base-boot-grub
      den.aspects.base-home-manager
      den.aspects.base-nix
      den.aspects.base-lix
      den.aspects.base-shell
      den.aspects.base-dns
    ];

    nixos = {host, ...}: let
      legacy_pkgs = import inputs.nixpkgs {
        inherit (host) system;
        overlays = self._channels.overlays;
        config.allowUnfree = true;
      };
    in {
      _module.args = {
        inherit globals inputs;
        mylib = import ../../lib {
          inherit globals inputs;
          pkgs = legacy_pkgs;
          inherit (legacy_pkgs) lib;
        };
      };

      nixpkgs.overlays = self._channels.overlays;
    };
  };
}
