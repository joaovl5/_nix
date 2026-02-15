{
  inputs,
  ...
}: {
  disko = import ./disko;
  modules = import ./modules;
  secrets = import ./secrets/base.nix {inherit inputs;};
}
