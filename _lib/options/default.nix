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
  def = lib.mkDefault;
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
  module = name: options: generation_settings: module_config: let
    opts = get_config_opts name;
  in {
    options.my.${name} = options;
    imports = (generation_settings.imports or (_: [])) opts;
    config = merge [
      (module_config opts)
      ((generation_settings.extra_opts or (_: {})) opts)
    ];
  };
  # _options = set_name:
}
