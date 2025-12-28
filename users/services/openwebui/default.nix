{pkgs, ...} @ args: let
  svc = import ../../../lib/services.nix args;
  inherit (svc) make_docker_service;
  http_port = 3939;
in
  make_docker_service {
    service_name = "technitium_dns";
    compose_obj = import ./compose.nix {inherit http_port;};
  }
  // {
    networking.firewall.allowedTCPPorts = [http_port];
  }
