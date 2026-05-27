{lav, ...}: {
  den.aspects.ai.homeManager = {
    pkgs,
    lib,
    ...
  }: let
    servers = lav.ai.mcp.servers {
      inherit pkgs lib;
    };
  in {
    programs.mcp = {
      enable = true;
      inherit servers;
    };
  };
}
