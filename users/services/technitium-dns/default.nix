{...}: let
  svc = import ../../../lib/services.nix;
in {
  config = svc.make_docker_service {
    service_name = "technitium-dns";
    arion_compose_source = ./arion-compose.nix;
  };
}
