{
  pkgs,
  config,
  lib,
  ...
} @ args: let
  inherit (import ../../../lib/services.nix args) make_docker_service;
  inherit (lib) mkOption mkIf mkMerge mkEnableOption types;
  cfg = config.my_nix.technitium_dns;
in {
  # TODO: make the bug of ther dns make dynamic config nixos valeu
  options.my_nix.technitium_dns = {
    enable =
      mkEnableOption "Enable Technitium DNS"
      // {
        default = false;
      };

    http_port = mkOption {
      description = "Port for http web UI";
      type = types.int;
      default = 5380;
    };

    hostname = mkOption {
      description = "Hostnames for local DNS";
      type = types.str;
      default = "dns.bigbug";
    };

    host_ip = mkOption {
      description = "IP for service, if it's hosted in another machine. Localhost by default.";
      type = types.str;
      default = "127.0.0.1";
    };
  };

  config = mkIf cfg.enable mkMerge [
    (make_docker_service {
      service_name = "technitium_dns";
      compose_obj = import ./compose.nix {inherit (cfg) http_port;};
    })

    {
      networking.firewall.allowedTCPPorts = [53 cfg.http_port];
      networking.firewall.allowedUDPPorts = [53];
    }
  ];
}
