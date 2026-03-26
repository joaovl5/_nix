{
  pkgs,
  lib,
}: let
  uvx = lib.getExe' pkgs.uv "uvx";
in {
  nixos = {
    command = lib.getExe pkgs.mcp-nixos;
  };

  fetch = {
    command = uvx;
    args = ["mcp-server-fetch"];
  };

  duckduckgo-search = {
    command = uvx;
    args = ["duckduckgo-mcp-server"];
  };
}
