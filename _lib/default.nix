args: {
  disko = import ./disko.nix;
  modules = import ./modules.nix;
  options = import ./options.nix args;
  secrets = import ./secrets.nix args;
  services = import ./services.nix args;
}
