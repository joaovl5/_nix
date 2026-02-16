{
  mylib,
  config,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  cfg = config.my;
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
            (o.when cfg."unit.pihole".enable (with cfg."unit.pihole"; {
              routers.pihole = {
                rule = "Host(`${dns.host_domain}`)";
                service = "pihole";
                entryPoints = ["web"];
              };
              services.pihole = {
                loadBalancer.servers = [
                  {url = "http://${dns.host_ip}:${toString web.port}";}
                ];
              };
            }))

            (o.when cfg."unit.litellm".enable (with cfg."unit.litellm"; {
              routers.litellm = {
                rule = "Host(`${web.host_domain}`)";
                service = "litellm";
                entryPoints = ["web"];
              };
              services.litellm = {
                loadBalancer.servers = [
                  {url = "http://${web.host_ip}:${toString web.port}";}
                ];
              };
            }))
          ];
        };
      }
  )
