{
  mylib,
  config,
  pkgs,
  inputs,
  lib,
  ...
}: let
  globals = import inputs.globals;

  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;

  inherit (globals.dns) tld;
in
  o.module "unit.fxsync" (with o; {
    enable = toggle "Enable Firefox Sync" false;
    endpoint = u.endpoint {
      port = 5000;
      target = "fxsync";
    };
    data_dir = optional "Directory for fxsync state data" t.str {};
  }) {} (opts:
    o.when opts.enable (let
      db_user = "syncstorage";
      db_port_syncstorage = 13306;
      db_port_tokenserver = 13307;
      domain = "https://${opts.endpoint.target}.${tld}";

      computed_data_dir =
        if opts.data_dir != null
        then opts.data_dir
        else "${u.data_dir}/fxsync";

      compose_obj = import ./compose.nix {
        data_dir = computed_data_dir;
        inherit db_port_syncstorage db_port_tokenserver;
      };
      docker_yaml = u.write_yaml_from_attrset "docker_compose_fxsync_db.yaml" compose_obj;
      user = config.my.nix.username;
      group = "users";
    in
      lib.mkMerge [
        {
          my.vhosts.fxsync = {
            inherit (opts.endpoint) target sources;
          };

          sops.secrets = {
            "fxsync_mariadb_password" = s.mk_secret_user "${s.dir}/fxsync.yaml" "mariadb_password" {};
            "fxsync_sync_master_secret" = s.mk_secret_user "${s.dir}/fxsync.yaml" "sync_master_secret" {};
            "fxsync_metrics_hash_secret" = s.mk_secret_user "${s.dir}/fxsync.yaml" "metrics_hash_secret" {};
          };

          system.activationScripts.ensure_data_directory_fxsync = ''
            echo "[!] Ensuring Fxsync directories and permissions"
            mkdir -v -p ${computed_data_dir}
            chown -R ${user}:${group} ${computed_data_dir}
          '';
        }
        (u.make_docker_unit {
          service_name = "fxsync-db";
          service_description = "Firefox Sync MariaDB";
          inherit compose_obj;
        })
        {
          systemd.user.services.fxsync-db.serviceConfig = {
            ExecStart = lib.mkForce (pkgs.writeShellScript "exec_start_fxsync_db" ''
              export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
              export MARIADB_USER=${db_user}
              export MARIADB_PASSWORD=$(cat ${s.secret_path "fxsync_mariadb_password"})
              exec docker compose -f ${docker_yaml} up
            '');
          };
        }
        {
          systemd.user.services.fxsync = {
            enable = true;
            description = "Firefox Sync Server";
            after = ["fxsync-db.service"];
            requires = ["fxsync-db.service"];
            wantedBy = ["default.target"];
            serviceConfig = {
              Type = "simple";
              Restart = "on-failure";
              RestartSec = "5s";
              ExecStart = pkgs.writeShellScript "exec_fxsync" ''
                export SYNC_HOST=0.0.0.0
                export SYNC_PORT=${toString opts.endpoint.port}
                export SYNC_HUMAN_LOGS=true
                export SYNC_MASTER_SECRET=$(cat ${s.secret_path "fxsync_sync_master_secret"})

                MARIADB_PASSWORD=$(cat ${s.secret_path "fxsync_mariadb_password"})
                export SYNC_SYNCSTORAGE__DATABASE_URL="mysql://${db_user}:$MARIADB_PASSWORD@127.0.0.1:${toString db_port_syncstorage}/syncstorage"
                export SYNC_SYNCSTORAGE__ENABLED=true

                export SYNC_TOKENSERVER__ENABLED=true
                export SYNC_TOKENSERVER__RUN_MIGRATIONS=true
                export SYNC_TOKENSERVER__NODE_TYPE=mysql
                export SYNC_TOKENSERVER__DATABASE_URL="mysql://${db_user}:$MARIADB_PASSWORD@127.0.0.1:${toString db_port_tokenserver}/tokenserver"
                export SYNC_TOKENSERVER__FXA_EMAIL_DOMAIN=api.accounts.firefox.com
                export SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL=https://oauth.accounts.firefox.com/v1
                export SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET=$(cat ${s.secret_path "fxsync_metrics_hash_secret"})
                export SYNC_TOKENSERVER__ADDITIONAL_BLOCKING_THREADS_FOR_FXA_REQUESTS=2
                export RUST_LOG=info

                exec ${pkgs.syncstorage-rs}/bin/syncserver
              '';
            };
          };
        }
        {
          systemd.user.services.fxsync-tokenserver-init = {
            enable = true;
            description = "Firefox Sync Tokenserver DB Init";
            after = ["fxsync.service"];
            requires = ["fxsync.service"];
            wantedBy = ["default.target"];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writeShellScript "fxsync_tokenserver_init" ''
                set -euo pipefail
                MARIADB_PASSWORD=$(cat ${s.secret_path "fxsync_mariadb_password"})
                RETRIES=10
                while [ $RETRIES -gt 0 ]; do
                  ${pkgs.mariadb}/bin/mysql \
                    --host=127.0.0.1 \
                    --port=${toString db_port_tokenserver} \
                    --user=${db_user} \
                    --password="$MARIADB_PASSWORD" \
                    tokenserver <<'SQL' && break
                INSERT IGNORE INTO services (id, service, pattern)
                  VALUES (1, 'sync-1.5', '{node}/1.5/{uid}');
                INSERT INTO nodes (id, service, node, available, current_load, capacity, downed, backoff)
                  VALUES (1, 1, '${domain}', 1, 0, 5, 0, 0)
                  ON DUPLICATE KEY UPDATE node='${domain}';
                SQL
                  echo "Waiting for tokenserver tables... ($RETRIES attempts left)"
                  sleep 5
                  ((RETRIES--))
                done
                [ $RETRIES -gt 0 ] || { echo "ERROR: tokenserver init failed"; exit 1; }
                echo "Tokenserver init complete"
              '';
            };
          };
        }
      ]))
