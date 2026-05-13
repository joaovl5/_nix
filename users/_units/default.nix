# Module for registering unit options to be used universally across hosts
{globals, ...}: let
  unit_global_cfg = globals.units;
in {
  imports = [
    # keep-sorted start
    ./actual-budget
    ./backup
    ./degoog
    ./fail2ban
    ./forgejo
    ./fxsync
    ./hermes-agent
    ./hister
    ./kaneo
    ./network_namespaces
    ./nixarr
    ./octodns
    ./pihole
    ./postgres
    ./qbittorrent
    ./reverse-proxy
    ./syncthing
    ./wireguard
    # keep-sorted end
    unit_global_cfg
  ];
}
