{
  config,
  pkgs,
  ...
} @ args: let
  o = import ../../../_lib/options.nix args;
  inherit (import ../../../_lib/services.nix {inherit pkgs config;}) make_docker_service data_dir;
  mount_path = "${data_dir}/technitium";
in
  # TODO: ^2 make the bug of ther dns make dynamic config nixos valeu
  o.module "technitium_dns" (with o; {
    enable = toggle "Enable Technitium DNS" false;
    http_port = opt "Port for http web UI" t.int 5380;
    hostname = opt "Hostnames for local DNS" t.str "dns.bigbug";
    host_ip = opt "IP for service, if it's hosted in another machine. Localhost by default." t.str "127.0.0.1";
  }) {} (
    opts:
      o.when opts.enable (o.merge [
        (make_docker_service {
          service_name = "technitium_dns";
          compose_obj = import ./compose.nix {
            http_port = opts.http_port;
            technitium_mount_path = mount_path;
          };
        })
        {
          # don't expose `http_port` here, since
          # traefik will handle proxy redirects
          networking.firewall.allowedTCPPorts = [53];
          networking.firewall.allowedUDPPorts = [53];
        }
      ])
  )
