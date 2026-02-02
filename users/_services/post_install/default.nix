{
  pkgs,
  config,
  ...
}: let
  cfg = config.my_nix;
  flake_path = cfg.flake_location;
  username = cfg.username;
  user_home = config.users.users.${username}.home;
in {
  # handle post-install on-boot tasks
  systemd.services.my_post_install_boot = {
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      # todo
      ExecStart = pkgs.writeShellScript "my_post_install_boot" ''
        # Copy SSH+AGE keys
      '';
    };
  };
  # handle post-install on-login tasks
  systemd.user.services.my_post_install_user = {
    wantedBy = ["default.target"];
    unitConfig = {
      ConditionPathExists = "!${flake_path}";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "my_post_install_user" ''
        flake_path="${flake_path}"
        repo_uri="git@github.com:joaovl5/_nix.git"
        git clone "$repo_uri" "$flake_path"
      '';
    };
  };
}
