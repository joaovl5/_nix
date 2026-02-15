{
  pkgs,
  config,
  ...
} @ args: let
  o = import ../../../_lib/options args;
  inherit (import ../../../_lib/services {inherit pkgs config;}) make_docker_service;
  http_port = 3939;
in
  o.module "openwebui" (with o; {
    enable = toggle "Enable OpenWebUI" true;
  }) {} (
    opts:
      o.when opts.enable (o.merge [
        (make_docker_service {
          service_name = "technitium_dns";
          compose_obj = import ./compose.nix {inherit http_port;};
        })
        {
          networking.firewall.allowedTCPPorts = [http_port];
        }
      ])
  )
