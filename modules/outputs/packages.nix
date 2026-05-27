{
  globals,
  inputs,
  self,
  ...
}: let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  local_packages = import ../_packages {inherit pkgs inputs;};
  octodns = import ../../lib/outputs/octodns.nix {inherit globals inputs self;};
in {
  flake.packages.${system} =
    {
      build_iso = self.nixosConfigurations.iso.config.system.build.isoImage;
      inherit
        (local_packages)
        degoog
        gopeed-web
        lidarr-plugins
        kaneo
        octodns-pihole
        pihole6api
        rumdl
        sane_fnlfmt
        tubifarry
        vm_launcher
        ;
    }
    // octodns;
}
