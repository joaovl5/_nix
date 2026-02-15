args: let
  base = import ./base.nix args;
  with_config = config: import ./with_config.nix (args // {inherit config;});
  use = config:
    let
      configured = with_config config;
    in
      base
      // configured
      // {
        inherit base with_config;
      };
in
  if args ? config
  then (use args.config) // {inherit use;}
  else (base // {inherit base with_config use;})
