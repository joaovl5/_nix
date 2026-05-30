{
  den,
  globals,
  inputs,
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
      den.aspects.cpp-nix
      # den.aspects.base-lix
      den.aspects.base-shell
      den.aspects.base-dns
    ];

    nixos = {pkgs, ...}: {
      _module.args = {
        inherit globals inputs;
        mylib = import ../../lib {
          inherit globals inputs pkgs;
          inherit (pkgs) lib;
        };
      };
    };
  };
}
