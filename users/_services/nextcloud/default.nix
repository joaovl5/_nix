{
  config,
  pkgs,
  ...
} @ args: let
  o = import ../../../_lib/options args;
  inherit (import ../../../_lib/services {inherit pkgs config;}) make_docker_service data_dir;
  mount_path = "${data_dir}/nextcloud";
in
  # options.my.nextcloud (past)
  o.module "nextcloud" (with o; {
    enable = toggle "Enable nextcloud" false;
    http_port = opt "Nextcloud's web UI port" t.int 1009;
    admin_user = opt "Admin user" t.str "admin";
    admin_password = opt "Admin password" t.str "adminchangeme";
    hostname = opt "Local DNS hostname" t.str "cloud.bigbug";
    host_ip = opt "IP for service" t.str "127.0.0.1";
  }) {} (
    opts:
      o.when opts.enable (o.merge [
        (make_docker_service {
          service_name = "nextcloud";
          compose_obj = import ./compose.nix {
            nextcloud_http_port = opts.http_port;
            nextcloud_admin_user = opts.admin_user;
            nextcloud_admin_password = opts.admin_password;
            nextcloud_trusted_domain = opts.hostname;
            nextcloud_mount_path = mount_path;
            mariadb_timezone = config.my.nix.timezone;
          };
        })
      ])
  )
