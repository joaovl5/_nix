{...} @ args: let
  svc = import ../../../lib/services.nix args;
  inherit (svc) make_docker_service;
in {
  config = make_docker_service {
    service_name = "technitium-dns";
    arion_compose_source = ./arion-compose.nix;
  };
}
