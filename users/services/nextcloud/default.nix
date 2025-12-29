{
  pkgs,
  config,
  lib,
  ...
} @ args: let
  inherit (import ../../../lib/services.nix args) make_docker_service;
  inherit (lib) mkOption mkIf mkMerge mkEnableOption types;
  cfg = config.my_nix.nextcloud;
in {
  # TODO: make the bug of ther dns make dynamic config nixos valeu
  options.my_nix.nextcloud = {
    enable =
      mkEnableOption "Enable Nextcloud"
      // {
        default = false;
      };

    http_port = mkOption {
      description = "Port for Nextcloud's web UI";
      type = types.int;
      default = 1009;
    };

    admin_user = mkOption {
      description = "Default admin user for Nextcloud";
      type = types.str;
      default = "admin";
    };

    admin_password = mkOption {
      description = "Default admin password for Nextcloud";
      type = types.str;
      default = "adminchangeme";
    };

    hostname = mkOption {
      description = "Hostname for local DNS";
      type = types.str;
      default = "cloud.bigbug";
    };

    host_ip = mkOption {
      description = "IP for service, if it's hosted in another machine. Localhost by default.";
      type = types.str;
      default = "127.0.0.1";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (make_docker_service {
      service_name = "nextcloud";
      compose_obj = import ./compose.nix {
        nextcloud_http_port = cfg.http_port;
        nextcloud_admin_user = cfg.admin_user;
        nextcloud_admin_password = cfg.admin_password;
        nextcloud_trusted_domains = cfg.hostname;
        mariadb_timezone = config.my_nix.timezone;
      };
    })
    # {
    #   networking.firewall.allowedTCPPorts = [53];
    #   networking.firewall.allowedUDPPorts = [53];
    # }
  ]);
}
