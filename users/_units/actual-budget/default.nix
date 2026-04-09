{
  mylib,
  config,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  u = my.units;
in
  o.module "unit.actual-budget" (with o; {
    enable = toggle "Enable Actual Budget" false;
    data_dir = optional "Directory for pihole state data" t.str {};
    endpoint = u.endpoint {
      port = 5006;
      target = "actual";
    };
  }) {} (opts: (o.when opts.enable (let
    computed_data_dir =
      if opts.data_dir != null
      then opts.data_dir
      else "${u.data_dir}/actual-budget";
    internal_data_dir = "/var/lib/actual";
    pkg = pkgs.actual-server;
  in {
    my.vhosts.actual-budget = {
      inherit (opts.endpoint) target sources;
    };

    my."unit.actual-budget".backup.items.state = {
      kind = "path";
      policy = "sensitive_data";
      path.paths = [internal_data_dir];
    };

    services = {
      actual = {
        enable = true;
        package = pkg;
        settings = {
          dataDir = internal_data_dir;
          inherit (opts.endpoint) port;
        };
      };
    };

    system.activationScripts.ensure_data_directory_actual_budget = ''
      echo "[!] Ensuring Actual Budget directories and symlinks"
      ln -sfn ${internal_data_dir} ${computed_data_dir}
    '';
  })))
