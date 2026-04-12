# TODO: support for mixed-modules (hm/nx) (see ./modules)
{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption;
  backup_types = import ../units/_backup/types.nix {inherit lib;};

  is_meta_import = value: builtins.typeOf value == "path";

  normalize_meta_module = name: raw: let
    raw_attrs =
      if lib.isAttrs raw
      then raw
      else throw "o.meta_module `${name}` expects an attrset with imports, options, and consumer functions.";
    imports = raw_attrs.imports or [];
    options = raw_attrs.options or {};
    consumer_attrs = builtins.removeAttrs raw_attrs ["imports" "options"];
    unsupported_keys =
      builtins.filter
      (key: !lib.isFunction consumer_attrs.${key})
      (builtins.attrNames consumer_attrs);
    bad_imports = builtins.filter (value: !is_meta_import value) imports;
    consumers = builtins.listToAttrs (builtins.map (key: {
      name = key;
      value = consumer_attrs.${key};
    }) (builtins.filter (key: lib.isFunction consumer_attrs.${key}) (builtins.attrNames consumer_attrs)));
  in
    if !lib.isString name || name == ""
    then throw "o.meta_module expects a non-empty string canonical name."
    else if !lib.isList imports
    then throw "o.meta_module `${name}` imports must be a list of file paths."
    else if !lib.isAttrs options
    then throw "o.meta_module `${name}` options must be an attrset."
    else if unsupported_keys != []
    then throw "o.meta_module `${name}` only accepts top-level imports, options, and consumer functions. Unsupported keys: ${builtins.concatStringsSep ", " unsupported_keys}"
    else if bad_imports != []
    then throw "o.meta_module `${name}` imports must contain only file paths."
    else
      {
        inherit name imports options;
      }
      // consumers;
in rec {
  t = lib.types;
  when = lib.mkIf;
  def = lib.mkDefault;
  force = lib.mkForce;
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

  meta_module = name: raw: normalize_meta_module name raw;
  # _options = set_name:
}
