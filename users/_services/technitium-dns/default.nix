{
  config,
  lib,
  ...
} @ args: let
  inherit (import ../../../_lib/services.nix args) make_docker_service data_dir;
  inherit (lib) mkOption mkIf mkMerge mkEnableOption types;
  cfg = config.my_nix.technitium_dns;
  mount_path = "${data_dir}/technitium";
in {
  # TODO: ^2 make the bug of ther dns make dynamic config nixos valeu
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

  config = mkIf cfg.enable (mkMerge [
    (make_docker_service {
      service_name = "technitium_dns";
      compose_obj = import ./compose.nix {
        inherit (cfg) http_port;
        technitium_mount_path = mount_path;
      };
    })

    {
      # don't expose `http_port` here, since
      # traefik will handle proxy redirects
      networking.firewall.allowedTCPPorts = [53];
      networking.firewall.allowedUDPPorts = [53];
    }
  ]);
}
