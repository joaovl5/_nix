{inputs, ...}: let
  globals = import inputs.globals;
  inherit (globals) hosts;
in {
  host_config = host: hosts.${host}.config;
  host_meta = host: hosts.${host}.meta or {};
}
