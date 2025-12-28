{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.my_nix;
  inherit (lib) mkIf mkMerge;
in {
  services.nginx = {
    # replace openssl with libressl
    package = pkgs.nginxStable.override {
      openssl = pkgs.libressl;
    };

    enable = true;
    recommendedProxySettings = true;

    virtualHosts = mkMerge [
      (mkIf cfg.technitium_dns.enable (with cfg.technitium_dns; {
        ${hostname}.locations."/" = {
          proxyPass = "http://${host_ip}:${http_port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_pass_header Authorization;
          '';
        };
      }))
    ];
  };
}
