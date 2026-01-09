{
  hm = {
    config,
    lib,
    ...
  }: let
    cfg = config.my_nix;
    secrets = config.sops.secrets;
    home_path = config.users.users.${cfg.username}.home;
    sync_dir = "${home_path}/${cfg.shared_data_dirname}";
  in {
    services.syncthing = {
      enable = false;
      # tray.enable = true;

      key = secrets.syncthing_pem_key.path;
      cert = secrets.syncthing_pem_cert.path;
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        options = {
          localAnnounceEnabled = true;
          relaysEnabled = true;
        };
        devices = {
          server = {
            name = "server";
            id = lib.readFile secrets.syncthing_server_id.path;
          };
        };
        folders = {
          sync = {
            path = sync_dir;
            type = "sendreceive";
            label = ".sync";
            devices = ["server"];
            versioning = [
              {
                versioning = {
                  type = "simple";
                  params.keep = "5"; # max. old versions to keep
                  params.cleanoutDays = "60"; # max days to keep for
                };
              }
            ];
          };
        };
      };
    };
  };
}
