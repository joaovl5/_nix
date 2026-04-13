{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption;
  t = lib.types;

  mk_route_type = protocol:
    t.submodule ({name, ...}: {
      options =
        {
          entry_point = mkOption {
            description = "Logical Traefik entry point name";
            type = t.str;
            default = name;
          };
          listen = {
            port = mkOption {
              description = "Traefik listen port";
              type = t.int;
            };
            address = mkOption {
              description = "Traefik listen address (defaults to :<listen.port> or :<listen.port>/udp)";
              type = t.nullOr t.str;
              default = null;
            };
            open_firewall = mkOption {
              description = "Expose this route through the firewall";
              type = t.bool;
              default = true;
            };
          };
          upstreams = mkOption {
            description = "Backend addresses for this route";
            type = t.listOf t.str;
            default = [];
          };
        }
        // lib.optionalAttrs (protocol == "tcp") {
          rule = mkOption {
            description = "Traefik TCP router rule";
            type = t.str;
            default = "HostSNI(`*`)";
          };
          tls = mkOption {
            description = "Optional Traefik TCP TLS settings";
            type = t.nullOr t.attrs;
            default = null;
          };
        };
    });

  route_entry_points = routes: map (route: route.entry_point) routes;
  route_has_upstreams = routes: builtins.all (route: route.upstreams != []) routes;
  route_entry_points_unique = routes:
    builtins.length (route_entry_points routes) == builtins.length (lib.unique (route_entry_points routes));

  route_ports_allowed = routes:
    builtins.all (route: !(builtins.elem route.listen.port [80 443])) routes;

  route_listen_address = protocol: route:
    if route.listen.address != null
    then route.listen.address
    else if protocol == "udp"
    then ":${toString route.listen.port}/udp"
    else ":${toString route.listen.port}";

  route_listen_addresses = protocol: routes: map (route: route_listen_address protocol route) routes;
  route_listen_addresses_unique = protocol: routes:
    builtins.length (route_listen_addresses protocol routes) == builtins.length (lib.unique (route_listen_addresses protocol routes));

  route_listen_address_matches_port = protocol: route: let
    address = route_listen_address protocol route;
    expected_suffix = ":${toString route.listen.port}";
    udp_address = lib.removeSuffix "/udp" address;
  in
    if protocol == "udp"
    then lib.hasSuffix "/udp" address && lib.hasSuffix expected_suffix udp_address
    else lib.hasSuffix expected_suffix address;

  route_listen_addresses_consistent = protocol: routes:
    builtins.all (route_listen_address_matches_port protocol) routes;
in {
  imports = [
    ./traefik
  ];

  options = {
    my = {
      vhosts = mkOption {
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

      tcp_routes = mkOption {
        description = "Traefik TCP route declarations";
        type = t.attrsOf (mk_route_type "tcp");
        default = {};
      };

      udp_routes = mkOption {
        description = "Traefik UDP route declarations";
        type = t.attrsOf (mk_route_type "udp");
        default = {};
      };
    };
  };

  config.assertions = [
    {
      assertion = route_has_upstreams (lib.attrValues config.my.tcp_routes);
      message = "my.tcp_routes entries must define at least one upstream.";
    }
    {
      assertion = route_has_upstreams (lib.attrValues config.my.udp_routes);
      message = "my.udp_routes entries must define at least one upstream.";
    }
    {
      assertion = route_entry_points_unique (lib.attrValues config.my.tcp_routes);
      message = "my.tcp_routes entry_point values must be unique.";
    }
    {
      assertion = route_entry_points_unique (lib.attrValues config.my.udp_routes);
      message = "my.udp_routes entry_point values must be unique.";
    }
    {
      assertion = route_ports_allowed (lib.attrValues config.my.tcp_routes);
      message = "my.tcp_routes listen.port cannot use Traefik reserved HTTP ports 80 or 443.";
    }
    {
      assertion = route_listen_addresses_consistent "tcp" (lib.attrValues config.my.tcp_routes);
      message = "my.tcp_routes listen.address must end with :<listen.port>.";
    }
    {
      assertion = route_listen_addresses_consistent "udp" (lib.attrValues config.my.udp_routes);
      message = "my.udp_routes listen.address must end with :<listen.port>/udp.";
    }
    {
      assertion = route_listen_addresses_unique "tcp" (lib.attrValues config.my.tcp_routes);
      message = "my.tcp_routes listen.address values must be unique.";
    }
    {
      assertion = route_listen_addresses_unique "udp" (lib.attrValues config.my.udp_routes);
      message = "my.udp_routes listen.address values must be unique.";
    }
  ];
}
