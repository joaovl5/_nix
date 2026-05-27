{
  mylib,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) concatMapStringsSep mkOption optional types;

  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;
  inherit (o) t;

  user = "slskd";
  media_group = "media";
  secret_file = "${s.dir}/slskd.yaml";
in
  o.module "unit.slskd" (with o; {
    enable = toggle "Enable slskd Soulseek service" false;
    package = mkOption {
      description = "slskd package to run";
      type = types.package;
      default = pkgs.slskd;
    };
    endpoint = u.endpoint {
      port = 55090;
      target = "soulseek";
    };
    state_dir = opt "slskd state directory" t.str "/var/lib/slskd";
    peer_port = opt "Soulseek peer listen port" t.int 50300;
    open_firewall = toggle "Open the Soulseek peer port in the firewall" true;
    download_dir = opt "Completed slskd download directory" t.str "/data/media/downloads/lidarr";
    incomplete_dir = opt "Incomplete slskd download directory" t.str "/data/media/downloads/slskd-incomplete";
    share_dirs = mkOption {
      description = "Directories shared with the Soulseek network";
      type = types.listOf types.str;
      default = ["/data/media/library/music"];
    };
  }) {} (opts:
      o.when opts.enable (let
        shared_args = concatMapStringsSep " \
" (dir: "--shared ${lib.escapeShellArg dir}") opts.share_dirs;
        start_slskd = pkgs.writeShellScript "start-slskd" ''
          set -euo pipefail

          api_key="$(${pkgs.coreutils}/bin/cat ${s.secret_path "slskd_api_key"})"
          username="$(${pkgs.coreutils}/bin/cat ${s.secret_path "slskd_username"})"
          password="$(${pkgs.coreutils}/bin/cat ${s.secret_path "slskd_password"})"
          soulseek_username="$(${pkgs.coreutils}/bin/cat ${s.secret_path "slskd_soulseek_username"})"
          soulseek_password="$(${pkgs.coreutils}/bin/cat ${s.secret_path "slskd_soulseek_password"})"

          exec ${opts.package}/bin/slskd \
            --app-dir ${lib.escapeShellArg opts.state_dir} \
            --http-ip-address 127.0.0.1 \
            --http-port ${toString opts.endpoint.port} \
            --no-https \
            --slsk-listen-port ${toString opts.peer_port} \
            --username "$username" \
            --password "$password" \
            --slsk-username "$soulseek_username" \
            --slsk-password "$soulseek_password" \
            --api-key "$api_key" \
            --downloads ${lib.escapeShellArg opts.download_dir} \
            --incomplete ${lib.escapeShellArg opts.incomplete_dir} \
            ${shared_args}
        '';
      in {
        assertions = [
          {
            assertion = config.nixarr.enable;
            message = "unit.slskd requires unit.nixarr.enable = true for media directories and group ownership";
          }
        ];

        my.vhosts.slskd = {
          inherit (opts.endpoint) target sources;
        };

        sops.secrets = {
          slskd_api_key = s.mk_secret secret_file "slskd_api_key" {
            owner = user;
            group = media_group;
          };
          slskd_username = s.mk_secret secret_file "slskd_username" {
            owner = user;
            group = media_group;
          };
          slskd_password = s.mk_secret secret_file "slskd_password" {
            owner = user;
            group = media_group;
          };
          slskd_soulseek_username = s.mk_secret secret_file "slskd_soulseek_username" {
            owner = user;
            group = media_group;
          };
          slskd_soulseek_password = s.mk_secret secret_file "slskd_soulseek_password" {
            owner = user;
            group = media_group;
          };
        };

        users.users.${user} = {
          isSystemUser = true;
          group = media_group;
          home = opts.state_dir;
        };

        systemd.tmpfiles.rules = [
          "d '/data/media/downloads' 2775 root ${media_group} - -"
          "d '${opts.state_dir}' 0750 ${user} ${media_group} - -"
          "d '${opts.download_dir}' 2775 ${user} ${media_group} - -"
          "d '${opts.incomplete_dir}' 2775 ${user} ${media_group} - -"
        ];

        networking.firewall.allowedTCPPorts = optional opts.open_firewall opts.peer_port;

        systemd.services.slskd = {
          description = "Soulseek daemon";
          wantedBy = ["multi-user.target"];
          after = ["network-online.target"];
          wants = ["network-online.target"];
          serviceConfig = {
            Type = "simple";
            User = user;
            Group = media_group;
            WorkingDirectory = opts.state_dir;
            StateDirectory = "slskd";
            StateDirectoryMode = "0750";
            UMask = "0002";
            Restart = "on-failure";
            RestartSec = "10s";
            ExecStart = start_slskd;
            ReadWritePaths = [
              opts.state_dir
              opts.download_dir
              opts.incomplete_dir
            ];
            ReadOnlyPaths = opts.share_dirs;
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
          };
        };
      }))
