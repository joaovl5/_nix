{
  mylib,
  config,
  pkgs,
  lib,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;
in
  o.module "unit.fxsync" (with o; {
    enable = toggle "Enable Firefox Sync" false;
    host = opt "Public URL domain" t.str "fxsync.lan";
    host_ip = opt "Host IP (used for DNS)" t.str "127.0.0.1";
    port = opt "Host port mapped to syncstorage:8000" t.int 5000;
    mariadb_user = opt "MariaDB user" t.str "syncstorage";
    data_dir = opt "Directory for fxsync state data" t.str "${u.data_dir}/fxsync";
  }) {} (opts:
    o.when opts.enable (let
      compose_obj = import ./compose.nix {inherit (opts) port data_dir;};
      docker_yaml = u.write_yaml_from_attrset "docker_compose_fxsync.yaml" compose_obj;
      user = config.my.nix.username;
      group = "users";
    in
      lib.mkMerge [
        {
          sops.secrets = {
            "fxsync_mariadb_password" = s.mk_secret_user "${s.dir}/fxsync.yaml" "mariadb_password" {};
            "fxsync_sync_master_secret" = s.mk_secret_user "${s.dir}/fxsync.yaml" "sync_master_secret" {};
            "fxsync_metrics_hash_secret" = s.mk_secret_user "${s.dir}/fxsync.yaml" "metrics_hash_secret" {};
          };

          system.activationScripts.ensure_data_directory_fxsync = ''
            echo "[!] Ensuring Fxsync directories and permissions"
            mkdir -v -p ${opts.data_dir}
            chown -R ${user}:${group} ${opts.data_dir}
          '';
        }
        (u.make_docker_unit {
          service_name = "fxsync";
          service_description = "Firefox Sync Server";
          inherit compose_obj;
        })
        {
          systemd.user.services.fxsync.serviceConfig = {
            ExecStart = lib.mkForce (pkgs.writeShellScript "exec_start_fxsync" ''
              export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
              export MARIADB_USER=${opts.mariadb_user}
              export MARIADB_PASSWORD=$(cat ${s.secret_path "fxsync_mariadb_password"})
              export SYNC_MASTER_SECRET=$(cat ${s.secret_path "fxsync_sync_master_secret"})
              export METRICS_HASH_SECRET=$(cat ${s.secret_path "fxsync_metrics_hash_secret"})
              export DOMAIN=http://${opts.host}
              mkdir -p ${opts.data_dir}/sync ${opts.data_dir}/token
              exec docker compose -f ${docker_yaml} up
            '');
          };
        }
      ]))
