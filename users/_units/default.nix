# Module for registering unit options to be used universally across hosts
{inputs, ...}: let
  globals = import inputs.globals;
  unit_global_cfg = globals.units;
in {
  imports = [
    ./backup
    ./actual-budget
    ./fail2ban
    ./pihole
    ./postgres
    ./kaneo
    ./nixarr
    ./reverse-proxy
    ./octodns
    ./fxsync
    ./wireguard
    ./qbittorrent
    ./syncthing
    ./forgejo
    unit_global_cfg
  ];
}
