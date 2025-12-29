{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.my_nix.nextcloud;
  minio_cfg = config.my_nix.minio;
in {
  options.my_nix.nextcloud = {
    enable =
      mkEnableOption "Enable Nextcloud"
      // {
        default = false;
      };
    use_minio =
      mkEnableOption "Uses Minio as object storage. Assumes it's enabled."
      // {
        default = true;
      };
    minio_bucket_name = mkOption {
      description = "If using Minio, what bucket name to use";
      type = types.str;
      default = "my_nextcloud";
    };
    http_port = mkOption {
      description = "Web port for Nextcloud";
      type = types.int;
      default = 9901;
    };
  };
  config = {
    # services.nextcloud = let
    #   package = pkgs.nextcloud28;
    # in {
    #   inherit package;
    #   enable = true;
    #   extraAppsEnable = true;
    #   extraApps = {
    #     inherit (package) news contacts calendar tasks;
    #   };
    #
    #   settings = {
    #     enabledPreviewProviders = [
    #       # image
    #       "OC\\Preview\\BMP"
    #       "OC\\Preview\\GIF"
    #       "OC\\Preview\\JPEG"
    #       "OC\\Preview\\HEIC"
    #       "OC\\Preview\\Krita"
    #       "OC\\Preview\\PNG"
    #       "OC\\Preview\\XBitmap"
    #       # doc
    #       "OC\\Preview\\MarkDown"
    #       "OC\\Preview\\OpenDocument"
    #       "OC\\Preview\\TXT"
    #       # audio
    #       "OC\\Preview\\MP3"
    #     ];
    #   };
    #
    #   config.objectstore.s3 = mkIf cfg.use_minio {
    #     enable = true;
    #     autocreate = true;
    #     useSsl = false;
    #     usePathStyle = true;
    #     region = "us-east-1";
    #     bucket = cfg.minio_bucket_name;
    #     key = minio_cfg.root_username;
    #     secretFile = "${pkgs.writeText "secret" minio_cfg.root_password}";
    #     hostname = minio_cfg.host_ip;
    #   };
    #
    #   https = false;
    # };
    # services.nginx.virtualHosts."localhost".listen = [
    #   {
    #     addr = "127.0.0.1";
    #     port = cfg.http_port;
    #   }
    # ];
  };
}
