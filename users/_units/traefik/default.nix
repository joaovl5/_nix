{
  mylib,
  config,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  cfg = config.my;
  _h = name: target: sources: opts:
    {inherit name target sources;} // opts;
  _u = host_ip: port: "http://${host_ip}:${toString port}";
  mk_host = hosts: let
    mk_router = host: {
      inherit (host) name;
      value = {
        rule = "Host(`${host.target}`)";
        service = host.name;
        entryPoints = ["web"];
      };
    };
    mk_service = host: {
      inherit (host) name;
      value = {
        loadBalancer.servers = map (source: {url = source;}) host.sources;
      };
    };
  in {
    routers = builtins.listToAttrs (map mk_router hosts);
    services = builtins.listToAttrs (map mk_service hosts);
  };
in
  o.module "traefik" (with o; {
    enable = toggle "Enable Traefik" true;
  }) {} (
    opts:
      o.when opts.enable {
        networking.firewall.allowedTCPPorts = [80 8080];
        services.traefik = {
          enable = true;
          staticConfigOptions = {
            entryPoints = {
              web.address = ":80";
              web.asDefault = true;
            };
            api.dashboard = true;
            api.insecure = true;
          };
          dynamicConfigOptions.http = o.merge [
            (with cfg."unit.pihole";
              o.when enable (
                mk_host [
                  (with dns; _h "pihole" host_domain [(_u host_ip web.port)] {})
                ]
              ))
            (with cfg."unit.litellm";
              o.when enable (
                mk_host [
                  (with web; _h "litellm" host_domain [(_u host_ip port)] {})
                ]
              ))
            (with cfg."unit.nixarr";
              o.when enable (
                mk_host [
                  (with jellyfin; _h "jellyfin" host [(_u host_ip port)] {})
                  (with prowlarr; _h "prowlarr" host [(_u host_ip port)] {})
                  (with lidarr; _h "lidarr" host [(_u host_ip port)] {})
                  (with radarr; _h "radarr" host [(_u host_ip port)] {})
                  (with sonarr; _h "sonarr" host [(_u host_ip port)] {})
                  (with bazarr; _h "bazarr" host [(_u host_ip port)] {})
                ]
              ))
            (with cfg."unit.soularr";
              o.when enable (
                mk_host [
                  (with slskd; _h "slskd" host [(_u host_ip port)] {})
                ]
              ))
          ];
        };
      }
  )
