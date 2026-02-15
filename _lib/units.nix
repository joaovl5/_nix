{config, ...}: let
  cfg = config.my.nix;
  home_path = config.users.users.${cfg.username}.home;
in {
  data_dir = "${home_path}/${cfg.private_data_dirname}/units";
}
