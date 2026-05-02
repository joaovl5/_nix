{
  globals,
  inputs,
}: let
  inherit (inputs) self;
  DEFAULT_SYSTEM = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${DEFAULT_SYSTEM};
  local_packages = import ../../packages {inherit pkgs inputs;};
  octodns = import ./octodns.nix {inherit globals inputs self;};
in {
  packages.${DEFAULT_SYSTEM} =
    {
      build_iso = let
        inherit (self.nixosConfigurations) iso;
      in
        iso.config.system.build.isoImage;
      inherit
        (local_packages)
        kaneo
        octodns-pihole
        pihole6api
        vm_launcher
        ;
    }
    // octodns;
}
