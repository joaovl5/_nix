{pkgs, ...} @ args: let
  svc = import ../../../lib/services.nix args;
  inherit (svc) make_docker_service;
in
  make_docker_service {
    service_name = "technitium_dns";
    compose_obj = import ./compose.nix {};
  }
  // {
    networking.firewall.allowedTCPPorts = [53 5380];
    networking.firewall.allowedUDPPorts = [53];
  }
