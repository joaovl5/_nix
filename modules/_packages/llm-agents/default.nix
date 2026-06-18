{
  pkgs,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  upstream = inputs.llm-agents.packages.${system};
in
  upstream
  // {
    inherit (pkgs) bun;
  }
