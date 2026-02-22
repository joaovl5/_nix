{
  mylib,
  config,
  inputs,
  pkgs,
  lib,
  ...
} @ args: let
  public = import ../../../../_modules/public.nix args;
  globals = import inputs.globals;

  my = mylib.use config;
  o = my.options;
  s = my.secrets;

  inherit (globals.dns) tld;
  inherit (config.my) vhosts;
in
  o.module "traefik" (with o; {
    enable = toggle "Enable Traefik reverse proxy" true;
  }) {} (opts:
    o.when opts.enable (let
      # Generate routers from vhosts
      routers =
        {
          traefik-dashboard = {
            rule = "Host(`traefik.${tld}`)";
            service = "api@internal";
            entryPoints = ["websecure"];
            tls.certResolver = "acme_resolver";
          };
        }
        // lib.mapAttrs (_name: vhost: {
          rule = "Host(`${vhost.target}.${tld}`)";
          service = _name;
          entryPoints = ["websecure"];
          tls.certResolver = "acme_resolver";
        })
        vhosts;

      # Generate services from vhosts
      services =
        lib.mapAttrs (_name: vhost: {
          loadBalancer.servers = map (source: {url = source;}) vhost.sources;
        })
        vhosts;
    in {
      sops.secrets = {
        "cloudflare_api_token" = s.mk_secret "${s.dir}/dns.yaml" "cloudflare-api-token" {};
      };

      networking.firewall.allowedTCPPorts = [80 443];

      # Prepare env file with CF_DNS_API_TOKEN before traefik starts
      systemd.services.traefik-prepare-env = {
        description = "Prepare Traefik environment file";
        before = ["traefik.service"];
        requiredBy = ["traefik.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "prepare-traefik-env" ''
            mkdir -p /run/traefik
            echo "CF_DNS_API_TOKEN=$(cat ${s.secret_path "cloudflare_api_token"})" > /run/traefik/env
            chmod 640 /run/traefik/env
            chown traefik:traefik /run/traefik/env
          '';
        };
      };

      services.traefik = {
        enable = true;
        environmentFiles = [
          "/run/traefik/env"
        ];
        staticConfigOptions = {
          entryPoints = {
            web = {
              address = ":80";
              http.redirections.entryPoint = {
                to = "websecure";
                scheme = "https";
              };
            };
            websecure = {
              address = ":443";
              asDefault = true;
            };
          };
          certificatesResolvers.acme_resolver.acme = {
            email = public.emails.google_2;
            storage = "/var/lib/traefik/acme.json";
            dnsChallenge = {
              provider = "cloudflare";
              resolvers = ["1.1.1.1:53"];
            };
          };
          api.dashboard = true;
        };
        dynamicConfigOptions.http = {
          inherit routers services;
        };
      };
    }))
