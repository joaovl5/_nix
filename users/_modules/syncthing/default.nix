{
  hm = {
    config,
    lib,
    mylib,
    nixos_config,
    ...
  }: let
    cfg = config.my.nix;
    s = (mylib.use nixos_config).secrets;
    home_path = nixos_config.users.users.${cfg.username}.home;
    sync_dir = "${home_path}/${cfg.shared_data_dirname}";
  in {
    services.syncthing = {
      enable = false;

      key = s.secret_path "syncthing_pem_key";
      cert = s.secret_path "syncthing_pem_cert";
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
            id = lib.readFile (s.secret_path "syncthing_server_id");
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
