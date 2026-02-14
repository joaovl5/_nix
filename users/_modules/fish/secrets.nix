{nixos_config, ...}: let
  inherit (nixos_config.sops) secrets;
  mk_secret = name: path: ''set -gx ${name} "$(cat ${path})"'';
  # var = name: value: "set -gx ${name} ${lib.escapeShellArg value}";
in ''
  ${mk_secret "OPENAI_KEY" "${secrets.openai_key.path}"}
''
