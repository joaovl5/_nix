{
  inputs,
  pkgs,
  lib,
  ...
}: {
  disko = import ./disko;
  modules = import ./modules;
  secrets = import ./secrets/base.nix {inherit inputs;};
  hosts = import ./hosts/base.nix {inherit inputs;};
  tests = import ./tests {inherit inputs pkgs lib;};
}
