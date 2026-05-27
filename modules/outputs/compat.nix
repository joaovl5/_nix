{
  globals,
  inputs,
  ...
}: let
  default_system = "x86_64-linux";

  module = obj: {attr ? "default"}: obj.nixosModules.${attr};
  lav = {
    inherit ((import ../public.nix {inherit inputs;}).lav) public;
  };
  aspect_nixos = path: args: name: (import path args).den.aspects.${name}.nixos;

  shared_modules = with inputs; [
    (module disko {})
    (module sops-nix {attr = "sops";})
    (module nixos-dns {attr = "dns";})
    (module hm {attr = "home-manager";})
    (aspect_nixos ../aspects/base/options.nix {} "base-options")
    (aspect_nixos ../aspects/base/secrets.nix {} "base-secrets")
    (aspect_nixos ../aspects/base/vm.nix {} "base-vm")
    (aspect_nixos ../aspects/base/boot-grub.nix {} "base-boot-grub")
    (aspect_nixos ../aspects/base/home-manager.nix {inherit lav;} "base-home-manager")
    (aspect_nixos ../aspects/base/nix.nix {} "base-nix")
    (aspect_nixos ../aspects/base/lix.nix {} "base-lix")
    (aspect_nixos ../aspects/base/shell.nix {} "base-shell")
    (aspect_nixos ../aspects/base/dns.nix {} "base-dns")
  ];
in {
  flake._utils.hosts = {
    inherit shared_modules;
    mk_extra_args = {pkgs, ...}: {
      mylib = import ../../lib {
        inherit globals inputs pkgs;
        inherit (pkgs) lib;
      };
      inherit globals inputs;
      system = default_system;
    };
  };
}
