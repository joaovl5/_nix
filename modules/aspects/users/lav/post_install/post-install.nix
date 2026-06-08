_: {
  den.aspects.user-lav-post-install.nixos = {
    pkgs,
    lib,
    config,
    mylib,
    ...
  }: let
    o = (mylib.use config).options;
    cfg = config.my.nix;
    inherit (cfg) username;
    user_home = config.users.users.${username}.home;

    install_script = pkgs.writeScript "my_post_install" ''
      #! /usr/bin/env python
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
              (python3.withPackages
                (ps: with ps; [cyclopts rich]))
            ];
            serviceConfig = {
              Type = "simple";
              ExecStart = "${install_script} --user ${username} ${user_home}";
            };
          };
        }
    );
}
