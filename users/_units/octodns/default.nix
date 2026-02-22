{
  mylib,
  config,
  inputs,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;

  octodns_config = inputs.self.packages.x86_64-linux.octodns;

  # Python environment with octodns and providers
  # NOTE: octodns-pihole is not in nixpkgs — needs packaging separately
  octodns_env = pkgs.python3.withPackages (_ps: [
    pkgs.octodns
    pkgs.octodns-providers.bind
    pkgs.octodns-providers.cloudflare
    # TODO: add octodns-pihole when packaged
  ]);
in
  o.module "unit.octodns" (with o; {
    enable = toggle "Enable OctoDNS sync service" false;
  }) {} (opts:
    o.when opts.enable {
      systemd.services.octodns-sync = {
        description = "OctoDNS zone sync to Pi-hole and Cloudflare";
        after = ["network-online.target" "pihole-ftl.service"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "octodns-sync" ''
            set -euo pipefail
            export PIHOLE_PASSWORD=$(cat ${s.secret_path "pihole_api_key"})
            export CLOUDFLARE_TOKEN=$(cat ${s.secret_path "cloudflare_api_token"})
            ${octodns_env}/bin/octodns-sync --config-file=${octodns_config} --doit
          '';
        };
      };
    })
