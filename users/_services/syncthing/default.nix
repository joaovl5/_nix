{
  pkgs,
  config,
  ...
}: let
  inherit (import ../../../_lib/services.nix {inherit pkgs config;}) make_docker_service data_dir;
  syncthing_dir = "${data_dir}/syncthing";
in {
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    key = config.sops.secrets.syncthing_pem_key.path;
    cert = config.sops.secrets.syncthing_pem_cert.path;

    dataDir = "${syncthing_dir}/data";
    configDir = "${syncthing_dir}/config";
  };
}
