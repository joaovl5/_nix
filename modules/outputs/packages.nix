{
  globals,
  inputs,
  self,
  ...
}: let
  system = "x86_64-linux";
  octodns = import ../../lib/outputs/octodns.nix {inherit globals inputs self;};
in {
  flake.packages.${system} =
    octodns;
}
