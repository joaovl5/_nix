{
  hm = {
    pkgs,
    lib,
    ...
  }: let
    servers = import ./_servers.nix {
      inherit pkgs lib;
    };
  in {
    programs.mcp = {
      enable = true;
      inherit servers;
    };
  };
}
