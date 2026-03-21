{
  mylib,
  config,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  u = my.units;
  inherit (o) t;
in
  o.module "unit.qbittorrent" (with o; {
    enable = toggle "Enable Qbittorrent" false;
    data_dir = optional "Directory for qbittorrent data" t.str {};
    endpoint = u.endpoint {
      port = 12011;
      target = "torrent";
    };
  }) {} (opts:
    o.when opts.enable (
      let
        computed_data_dir =
          if opts.data_dir != null
          then opts.data_dir
          else "${u.data_dir}/qbittorrent";
        internal_data_dir = "/var/lib/qBittorrent/qBittorrent/downloads";
      in
        o.merge [
          {
            my.vhosts.qbittorrent = {
              inherit (opts.endpoint) target sources;
            };
            services.qbittorrent = {
              enable = true;
              webuiPort = opts.endpoint.port;
              extraArgs = [
                "--confirm-legal-notice"
              ];
              serverConfig = {
                Preferences.WebUI = {
                  AlternativeUIEnabled = true;
                  RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
                };
              };
            };
            system.activationScripts.ensure_data_directory_qbittorrent = ''
              echo "[!] Ensuring Qbittorrent directories and symlinks"
              ln -sfn ${internal_data_dir} ${computed_data_dir}
            '';
          }
        ]
    ))
