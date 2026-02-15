{pkgs, ...} @ args: let
  o = import ../../../_lib/options args;
in
  o.module "minio" (with o; {
    enable = toggle "Enable Minio" false;
    listen_port = opt "Listen port for Minio" t.int 9900;
    console_port = opt "Console port for Minio" t.int 9901;
    root_username = opt "Root username for Minio" t.str "root";
    root_password = opt "Root password for Minio" t.str "pleasechangeme000";
    host_ip = opt "Host ip for Nextcloud" t.str "127.0.0.1";
  }) {} (
    opts:
      o.when opts.enable {
        services.minio = {
          enable = true;
          listenAddress = "0.0.0.0:${toString opts.listen_port}";
          consoleAddress = "0.0.0.0:${toString opts.console_port}";
          rootCredentialsFile = pkgs.writeText "minio-credentials-full" ''
            MINIO_ROOT_USER=${opts.root_username}
            MINIO_ROOT_PASSWORD=${opts.root_password}
          '';
        };
      }
  )
