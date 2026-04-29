{
  nx = {
    config,
    mylib,
    ...
  }: let
    my = mylib.use config;
    s = my.secrets;
  in {
    sops.secrets.hister_client_access_token = s.mk_secret_user "${s.dir}/hister.yaml" "access_token" {};
  };

  hm = {
    lib,
    pkgs,
    inputs,
    nixos_config,
    ...
  }: let
    hister_pkg = inputs.hister.packages.${pkgs.stdenvNoCC.hostPlatform.system}.default;
    token_path = nixos_config.sops.secrets.hister_client_access_token.path;
    server_url = "https://hister.trll.ing";

    hister_wrapper = pkgs.writeShellScriptBin "hister" ''
      set -euo pipefail
      export HISTER_DATA_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/hister"
      token="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg token_path})"
      if [ -z "$token" ]; then
        echo "Hister access token secret is empty" >&2
        exit 1
      fi
      export HISTER__APP__ACCESS_TOKEN="$token"
      exec ${lib.getExe hister_pkg} --server-url ${lib.escapeShellArg server_url} "$@"
    '';

    hister_raw = pkgs.runCommand "hister-raw" {} ''
      mkdir -p "$out/bin"
      ln -s ${lib.getExe hister_pkg} "$out/bin/hister-raw"
    '';
  in {
    home.packages = [
      hister_wrapper
      hister_raw
    ];
  };
}
