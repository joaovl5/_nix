{
  inputs,
  lib,
  ...
}: let
  globals = import inputs.globals;
  inherit (globals) hosts;
  host_helpers = import ../_lib/hosts/base.nix {inherit inputs;};
  loader = import ./_loader.nix {inherit lib;};
  schema = import ./_schema.nix {inherit lib;};
  loaded = loader (import ./modules.nix);
  inherit (loaded) registry;
  evaluation = schema {
    inherit hosts registry;
  };

  mk_consumer_modules = consumer_name: validated:
    builtins.concatLists (builtins.map (
        module_name: let
          module = registry.${module_name};
        in
          if builtins.hasAttr consumer_name module && validated.modules.${module_name} != null
          then [
            (args: let
              pkgs = args.pkgs or import inputs.nixpkgs {
                system = args.system or "x86_64-linux";
              };
            in
              module.${consumer_name} (args
                // {
                  inherit pkgs;
                  opts = validated.modules.${module_name};
                  meta = validated;
                }))
          ]
          else []
      )
      loaded.order);
in {
  inherit registry evaluation;
  modules = registry;
  inherit (loaded) order;
  for_host = host: let
    host_meta = host_helpers.host_meta host;
    has_validated = builtins.hasAttr host evaluation.config.hosts;
    validated =
      if has_validated
      then evaluation.config.hosts.${host}
      else {modules = {};};
  in {
    inherit host_meta;
    meta = validated;
    nx_modules =
      if has_validated
      then mk_consumer_modules "nx" validated
      else [];
    hm_modules =
      if has_validated
      then mk_consumer_modules "hm" validated
      else [];
  };
}
