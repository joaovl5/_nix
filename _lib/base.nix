{
  inputs,
  pkgs,
  lib,
  ...
}: {
  disko = import ./disko;
  hosts = import ./hosts/base.nix {inherit inputs;};
  meta = import ../meta/default.nix {inherit inputs lib;};
  modules = import ./modules;
  secrets = import ./secrets/base.nix {inherit inputs;};
  tests = import ./tests {inherit inputs pkgs lib;};
}
