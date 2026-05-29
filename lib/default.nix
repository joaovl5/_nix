args: let
  pkgs_for = config:
    if args ? pkgs && args.pkgs != null
    then args.pkgs
    else config._module.args.pkgs;
  lib_for = config:
    if args ? lib && args.lib != null
    then args.lib
    else (pkgs_for config).lib;
  base = import ./base.nix args;
  with_config = config: let
    pkgs = pkgs_for config;
    lib = lib_for config;
  in
    import ./with_config.nix (args // {inherit config pkgs lib;});
  use = config: let
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
