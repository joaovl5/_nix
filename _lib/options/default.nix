# TODO: support for mixed-modules (hm/nx) (see ./modules)
{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption;
  backup_types = import ../units/_backup/types.nix {inherit lib;};
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

  with_backup_items = options:
    lib.recursiveUpdate options {
      backup.items = opt "Backup items owned by this unit" (t.attrsOf backup_types.BackupItem) {};
    };

  toggle = description: default: (opt description t.bool default);
  get_config_opts = key: config.my.${key};
  module = name: options: generation_settings: module_config: let
    opts = get_config_opts name;
  in {
    options.my.${name} = with_backup_items options;
    imports = (generation_settings.imports or (_: [])) opts;
    config = merge [
      (module_config opts)
      ((generation_settings.extra_opts or (_: {})) opts)
    ];
  };
  # _options = set_name:
}
