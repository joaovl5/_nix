{globals, ...}: let
  inherit (globals) hosts;
in {
  host_config = host: hosts.${host}.config;
}
