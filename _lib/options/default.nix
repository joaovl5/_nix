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
  opt = description: type: default: (mkOption {
    inherit
      description
      type
      default
      ;
  });
  toggle = description: default: (opt description t.bool default);
  module = name: options: _generation_settings: module_config: let
    opts = config.my.${name};
  in {
    options.my.${name} = options;
    config = module_config opts;
  };
  # _options = set_name:
}
