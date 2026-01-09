{
  pkgs,
  config,
  lib,
  ...
} @ args: let
  inherit (import ../../../lib/services.nix args) data_dir;
  cfg = config.my_nix;
  secrets = config.sops.secrets;
  syncthing_dir = "${data_dir}/syncthing";
  inherit (lib) mkIf mkMerge;
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
