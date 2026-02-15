{
  pkgs,
  config,
  ...
} @ args: let
  o = import ../../../_lib/options.nix args;
  inherit (import ../../../_lib/services.nix {inherit pkgs config;}) data_dir;
  syncthing_dir = "${data_dir}/syncthing";
in
  o.module "syncthing" (with o; {
    enable = toggle "Enable Syncthing" true;
  }) {} (
    opts:
      o.when opts.enable {
        services.syncthing = {
          enable = true;
          openDefaultPorts = true;
          key = config.sops.secrets.syncthing_pem_key.path;
          cert = config.sops.secrets.syncthing_pem_cert.path;

          dataDir = "${syncthing_dir}/data";
          configDir = "${syncthing_dir}/config";
        };
      }
  )
