{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.my_nix.minio;
in {
  options.my_nix.minio = {
    enable =
      mkEnableOption "Enable Minio"
      // {
        default = false;
      };

    listen_port = mkOption {
      description = "Listen port for Minio";
      type = types.int;
      default = 9900;
    };

    console_port = mkOption {
      description = "Console port for Minio";
      type = types.int;
      default = 9901;
    };

    root_username = mkOption {
      description = "Root username for Minio";
      type = types.str;
      default = "root";
    };
    root_password = mkOption {
      description = "Root password for Minio";
      type = types.str;
      default = "pleasechangeme000";
    };

    host_ip = mkOption {
      description = "Host ip for Nextcloud";
      type = types.str;
      default = "127.0.0.1";
    };
  };
  config = {
    services.minio = mkIf cfg.enable {
      enable = true;
      listenAddress = "0.0.0.0:${toString cfg.listen_port}";
      consoleAddress = "0.0.0.0:${toString cfg.console_port}";
      rootCredentialsFile = pkgs.writeText "minio-credentials-full" ''
        MINIO_ROOT_USER=${cfg.root_username}
        MINIO_ROOT_PASSWORD=${cfg.root_password}
      '';
    };
  };
}
