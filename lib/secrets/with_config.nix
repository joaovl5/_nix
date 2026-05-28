{
  inputs,
  config,
  ...
}: let
  private_source = inputs.mysecrets;
  cfg = config.my.nix;
in rec {
  inherit private_source;

  dir = "${private_source}/secrets";
  mk_secret = file: key: opts:
    {
      inherit key;
      sopsFile = file;
      owner = "root";
      group = "root";
      mode = "0400";
    }
    // opts;

  mk_secret_user = file: key: opts: (mk_secret file key (opts // {owner = cfg.username;}));

  secret_path = name: config.sops.secrets.${name}.path;
}
