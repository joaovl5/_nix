args: {
  options = import ./options args;
  secrets = import ./secrets/with_config.nix args;
  services = import ./services args;
  units = import ./units args;
}
