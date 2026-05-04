{
  mylib,
  nixos_config,
  ...
}: let
  s = (mylib.use nixos_config).secrets;
  mk_secret = name: path: ''set -gx ${name} "$(cat ${path})"'';
in ''
  ${mk_secret "OPENAI_KEY" (s.secret_path "openai_key")}
  ${mk_secret "OPENAI_API_KEY" (s.secret_path "openai_key")}
''
