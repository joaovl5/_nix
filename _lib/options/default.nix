# TODO: support for mixed-modules (hm/nx) (see ./modules)
{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption;
in rec {
  t = lib.types;
  when = lib.mkIf;
  merge = lib.mkMerge;
  opt = description: type: default: (mkOption (
    {
      inherit
        description
        type
        ;
    }
    // (
      if (default != null)
      then {inherit default;}
      else {}
    )
  ));
  optional = description: type: args: (mkOption {
      inherit description;
      type = t.nullOr type;
      default = null;
    }
    // args);

  toggle = description: default: (opt description t.bool default);
  get_config_opts = key: config.my.${key};
  module = name: options: _generation_settings: module_config: let
    opts = get_config_opts name;
  in {
    options.my.${name} = options;
    config = module_config opts;
  };
  # _options = set_name:
}
