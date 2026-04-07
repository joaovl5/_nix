{
  nx = {lib, ...}: {
    options.my.syncthing.server_device_id = lib.mkOption {
      type = lib.types.str;
      description = "Syncthing device ID for the storage server peer.";
    };
  };

  hm = {
    config,
    lib,
    nixos_config,
    ...
  }: let
    inherit (lib) mkEnableOption mkIf mkOption types;

    cfg = config.my.syncthing;
    server_cfg = nixos_config.my.syncthing;
    home_path = config.home.homeDirectory;
    src_dir = "${home_path}/src";
    src_ignore_patterns = import ../storage/src_ignore_patterns.nix;
  in {
    options.my.syncthing = {
      enable = mkEnableOption "Syncthing client";

      server_name = mkOption {
        type = types.str;
        default = "tyrant";
        description = "Syncthing peer name for the storage server.";
      };
    };

    config = mkIf cfg.enable {
      services.syncthing = {
        enable = true;

        key = nixos_config.sops.secrets.syncthing_lavpc_pem_key.path;
        cert = nixos_config.sops.secrets.syncthing_lavpc_pem_cert.path;
        overrideDevices = true;
        overrideFolders = true;
        settings = {
          options = {
            localAnnounceEnabled = true;
            relaysEnabled = true;
          };
          devices.${cfg.server_name} = {
            name = cfg.server_name;
            id = server_cfg.server_device_id;
          };
          folders.src = {
            path = src_dir;
            type = "sendreceive";
            label = "src";
            devices = [cfg.server_name];
            ignorePatterns = src_ignore_patterns;
          };
        };
      };
    };
  };
}
