{
  config,
  ...
} @ args: let
  o = import ../../../_lib/options args;
  inherit (config) my;
in
  o.module "traefik" (with o; {
    enable = toggle "Enable Traefik" true;
  }) {} (
    opts:
      o.when opts.enable {
        networking.firewall.allowedTCPPorts = [80];
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
            (o.when my.technitium_dns.enable (with my.technitium_dns; {
              routers.technitium_dns = {
                rule = "Host(`${hostname}`)";
                service = "technitium_dns";
                entryPoints = ["web"];
              };
              services.technitium_dns = {
                loadBalancer.servers = [
                  {url = "http://${host_ip}:${toString http_port}";}
                ];
              };
            }))
            (o.when my.nextcloud.enable (with my.nextcloud; {
              routers.nextcloud = {
                rule = "Host(`${hostname}`)";
                service = "nextcloud";
                entryPoints = ["web"];
              };
              services.nextcloud = {
                loadBalancer.servers = [
                  {url = "http://${host_ip}:${toString http_port}";}
                ];
              };
            }))
          ];
        };
      }
  )
