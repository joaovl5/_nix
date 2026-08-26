{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.my.nix;
  home_path = config.users.users.${cfg.username}.home;
  backup = import ./_backup {
    inherit config pkgs lib;
  };
  endpoint = import ./endpoint.nix {inherit lib;};
in {
  inherit backup endpoint;
  data_dir = "${home_path}/${cfg.private_data_dirname}/units";

  write_yaml_from_attrset = name: attrset:
    pkgs.runCommand name {
      nativeBuildInputs = [pkgs.yj];
      json = builtins.toJSON attrset;
    } ''
      printf '%s' "$json" | yj -jy > "$out"
    '';
}
