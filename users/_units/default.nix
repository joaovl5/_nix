# Module for registering unit options to be used universally across hosts
{inputs, ...}: let
  globals = import inputs.globals;
  unit_global_cfg = globals.units;
in {
  imports = [
    ./actual-budget
    ./pihole
    ./litellm
    ./nixarr
    ./soularr
    ./reverse-proxy
    ./octodns
    ./fxsync
    ./wireguard
    ./qbittorrent
    unit_global_cfg
  ];
}
