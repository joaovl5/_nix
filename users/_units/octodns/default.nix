{
  mylib,
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  t = lib.types;
  local_packages = import ../../../packages {inherit pkgs inputs;};

  # Python environment with octodns and providers
  # octodns-pihole is not in nixpkgs — needs packaging separately
  octodns_env = pkgs.python3.withPackages (_: [
    pkgs.octodns
    pkgs.octodns-providers.bind
    pkgs.octodns-providers.cloudflare
    local_packages.octodns-pihole
  ]);

  vhost_policy_dir =
    pkgs.writeTextDir "octodns_vhost_policy.py"
    (builtins.readFile ./octodns_vhost_policy.py);
in
  o.module "unit.octodns" (with o; {
    enable = toggle "Enable OctoDNS sync service" false;
    config_package = opt "Optional OctoDNS config package output used by octodns-sync" (t.nullOr t.package) null;
    config_path = opt "Explicit OctoDNS config path passed to octodns-sync" (t.nullOr t.path) null;
    use_cloudflare_token = opt "Export CLOUDFLARE_TOKEN for OctoDNS providers that need it" t.bool true;
  }) {} (opts:
    o.when opts.enable (
      let
        default_octodns_config = inputs.self.packages.x86_64-linux.octodns;
        octodns_config =
          if opts.config_path != null
          then opts.config_path
          else if opts.config_package != null
          then opts.config_package
          else default_octodns_config;
      in {
        systemd.services.octodns-sync = {
          description = "OctoDNS zone sync service";
          wantedBy = ["multi-user.target" "pihole-ftl.service"];
          after = ["network-online.target" "pihole-ftl.service" "pihole-pwhash.service" "pihole-ftl-setup.service"];
          wants = ["network-online.target"];
          requires = ["pihole-ftl-setup.service"];
          partOf = ["pihole-ftl.service" "pihole-ftl-setup.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = pkgs.writeShellScript "octodns-sync" ''
              set -euo pipefail
              export PYTHONPATH="${vhost_policy_dir}:''${PYTHONPATH:-}"
              export PIHOLE_PASSWORD=$(cat ${s.secret_path "pihole_password"})
              ${lib.optionalString opts.use_cloudflare_token ''
                export CLOUDFLARE_TOKEN=$(cat ${s.secret_path "cloudflare_api_token"})
              ''}
              ${octodns_env}/bin/octodns-sync --config-file=${octodns_config} --force --doit
            '';
          };
        };
      }
    ))
