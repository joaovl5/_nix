{
  config,
  lib,
  ...
}: let
  cfg = config.my_nix;
  inherit (lib) mkIf mkMerge;
in {
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
    dynamicConfigOptions.http = mkMerge [
      (mkIf cfg.technitium_dns.enable (with cfg.technitium_dns; {
        routers.technitium_dns = {
          rule = "Host(`${hostname}`)";
          service = "technitium_dns";
          entryPoints = ["web"];
        };
        # services.technitium_dns = {
        #   loadBalancer.servers = ["http://${host_ip}:${builtins.toString http_port}"];
        # };
      }))
    ];
  };
}
