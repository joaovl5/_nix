args: {
  options = import ./options args;
  secrets = import ./secrets/with_config.nix args;
  units = import ./units args;
}
