{lib, ...}: let
  inherit (lib) mkOption;
  t = lib.types;
in {
  imports = [
    ./traefik
  ];

  options.my.vhosts = mkOption {
    description = "Virtual host declarations consumed by reverse proxy and DNS modules";
    type = t.attrsOf (t.submodule {
      options = {
        target = mkOption {
          description = "Subdomain prefix (without TLD)";
          type = t.str;
        };
        sources = mkOption {
          description = "List of upstream URLs for reverse proxy load balancing";
          type = t.listOf t.str;
        };
      };
    });
    default = {};
  };
}
