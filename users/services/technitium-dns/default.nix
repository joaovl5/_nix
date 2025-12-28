{pkgs, ...} @ args: let
  svc = import ../../../lib/services.nix args;
  inherit (svc) make_docker_service;
in
  make_docker_service {
    service_name = "technitium_dns";
    compose_obj = import ./compose.nix;
  }
