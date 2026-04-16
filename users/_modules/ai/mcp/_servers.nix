{
  pkgs,
  lib,
}: let
  exe = pkg: (lib.getExe pkgs.${pkg});
in {
  nixos = {
    command = exe "mcp-nixos";
  };
}
