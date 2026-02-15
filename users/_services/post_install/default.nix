{
  pkgs,
  lib,
  config,
  ...
} @ args: let
  o = import ../../../_lib/options.nix args;
  cfg = config.my.nix;
  inherit (cfg) username;
  user_home = config.users.users.${username}.home;

  install_script = pkgs.writeScript "my_post_install" ''
    ${lib.readFile ./src/handle_post_install.py}
  '';
in
  o.module "post_install" (with o; {
    enable = toggle "Enable post-install tasks" true;
  }) {} (
    opts:
      o.when opts.enable {
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
  )
