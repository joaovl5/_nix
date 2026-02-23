# Module for registering unit options to be used universally across hosts
{inputs, ...}: let
  globals = import inputs.globals;
  unit_global_cfg = globals.units;
in {
  imports = [
    ./pihole
    ./litellm
    ./nixarr
    ./soularr
    ./reverse-proxy
    ./octodns
    ./fxsync
    unit_global_cfg
  ];
}
