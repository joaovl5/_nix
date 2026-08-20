{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption;
  abbrs = config.shell-abbrs;
  t = lib.types;
in {
  options.shell-abbrs = mkOption {
    default = {};
    type = t.attrsOf t.str;
  };
  config.programs.fish.shellAbbrs = abbrs;
}
