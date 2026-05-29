{
  globals,
  inputs,
  ...
}: let
  default_system = "x86_64-linux";
in {
  flake._utils.hosts = {
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
