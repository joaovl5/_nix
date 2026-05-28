# Called as: u.endpoint { port = 8096; target = "jellyfin"; }
# Returns an attrset of options suitable for embedding in o.module declarations.
{lib, ...}: let
  inherit (lib) mkOption;
  t = lib.types;
in
  {
    port ? 80,
    target ? "service",
  }: {
    port = mkOption {
      description = "Port for this service";
      type = t.int;
      default = port;
    };
    target = mkOption {
      description = "Subdomain prefix (without TLD)";
      type = t.str;
      default = target;
    };
    sources = mkOption {
      description = "List of upstream URLs for reverse proxy load balancing";
      type = t.listOf t.str;
      default = ["http://localhost:${toString port}"];
    };
  }
