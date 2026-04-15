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
  o.module "unit.traefik" (with o; {
    enable = toggle "Enable Traefik reverse proxy" false;
  }) {} (opts:
    lib.mkMerge [
      {
        # secrets have to be declared outside of `o.when` to appear at eval for other hosts
        sops.secrets = {
          "cloudflare_api_token" = s.mk_secret "${s.dir}/dns.yaml" "cloudflare-api-token" {};
        };
      }
      (o.when opts.enable (
        let
          inherit (config.my) tcp_routes;
          inherit (config.my) udp_routes;

          route_listen_address = prefix: route:
            if route.listen.address != null
            then route.listen.address
            else if prefix == "udp"
            then ":${toString route.listen.port}/udp"
            else ":${toString route.listen.port}";

          mk_entrypoints = prefix: routes:
            lib.mapAttrs' (_name: route:
              lib.nameValuePair "${prefix}_${route.entry_point}" {
                address = route_listen_address prefix route;
              })
            routes;

          mk_routers = prefix: routes:
            lib.mapAttrs (_name: route:
              {
                entryPoints = ["${prefix}_${route.entry_point}"];
                service = _name;
              }
              // lib.optionalAttrs (prefix == "tcp") {
                inherit (route) rule;
              }
              // lib.optionalAttrs (prefix == "tcp" && route.tls != null) {
                inherit (route) tls;
              })
            routes;

          mk_services = routes:
            lib.mapAttrs (_name: route: {
              loadBalancer.servers = map (upstream: {address = upstream;}) route.upstreams;
            })
            routes;

          static_entrypoints =
            {
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
            }
            // mk_entrypoints "tcp" tcp_routes
            // mk_entrypoints "udp" udp_routes;

          routers =
            {
              traefik-dashboard = {
                rule = "Host(`traefik.${tld}`)";
                service = "api@internal";
                entryPoints = ["websecure"];
                tls.certResolver = "acme_resolver";
                middlewares = ["lan-only"];
              };
            }
            // lib.mapAttrs (_name: vhost:
              {
                rule = "Host(`${vhost.target}.${tld}`)";
                service = _name;
                entryPoints = ["websecure"];
                tls.certResolver = "acme_resolver";
              }
              // lan_only_middleware vhost.target)
            vhosts;

          # Determine which vhosts need lan-only restriction
          lan_only_middleware = name:
            if builtins.elem name globals.dns.public_vhosts
            then {}
            else {middlewares = ["lan-only"];};

          # Generate services from vhosts
          services =
            lib.mapAttrs (_name: vhost: {
              loadBalancer.servers = map (source: {url = source;}) vhost.sources;
            })
            vhosts;

          tcp_firewall_ports = map (route: route.listen.port) (lib.filter (route: route.listen.open_firewall) (lib.attrValues tcp_routes));
          udp_firewall_ports = map (route: route.listen.port) (lib.filter (route: route.listen.open_firewall) (lib.attrValues udp_routes));
        in {
          networking.firewall.allowedTCPPorts = lib.unique ([80 443] ++ tcp_firewall_ports);
          networking.firewall.allowedUDPPorts = lib.unique udp_firewall_ports;

          my."unit.traefik".backup.items.acme = {
            kind = "path";
            policy = "critical_infra";
            path.paths = ["/var/lib/traefik/acme.json"];
          };

          # Prepare env file with CF_DNS_API_TOKEN before traefik starts
          systemd.services.traefik-prepare-env = {
            description = "Prepare Traefik environment file";
            before = ["traefik.service"];
            requiredBy = ["traefik.service"];
            partOf = ["traefik.service"];
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
              entryPoints = static_entrypoints;
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
            dynamicConfigOptions =
              {
                http = {
                  inherit routers services;
                  middlewares.lan-only.ipAllowList.sourceRange = [
                    "192.168.15.0/24"
                    "127.0.0.1/32"
                  ];
                };
              }
              // lib.optionalAttrs (tcp_routes != {}) {
                tcp = {
                  routers = mk_routers "tcp" tcp_routes;
                  services = mk_services tcp_routes;
                };
              }
              // lib.optionalAttrs (udp_routes != {}) {
                udp = {
                  routers = mk_routers "udp" udp_routes;
                  services = mk_services udp_routes;
                };
              };
          };
        }
      ))
    ])
