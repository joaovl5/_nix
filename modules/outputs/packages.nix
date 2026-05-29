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
      inherit
        (local_packages)
        vm_launcher
        ;
    }
    // octodns;
}
