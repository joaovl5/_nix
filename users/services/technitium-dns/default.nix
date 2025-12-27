{pkgs, ...} @ args: let
  svc = import ../../../lib/services.nix args;
  inherit (svc) make_docker_service;
in
  make_docker_service {
    service_name = "technitium-dns";
    compose_file = ./arion-compose.nix;
  }
