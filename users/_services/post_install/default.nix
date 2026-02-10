{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.my_nix;
  username = cfg.username;
  user_home = config.users.users.${username}.home;

  install_script = pkgs.writeScript "my_post_install" ''
    ${lib.readFile ./src/handle_post_install.py}
  '';
in {
  # handle post-install tasks, during boot
  systemd.services.my_post_install = {
    wantedBy = ["multi-user.target"];
    path = with pkgs; [
      uv
    ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${install_script} --user ${username} ${user_home}";
    };
  };
}
