{inputs, ...}: let
  private_source = inputs.mysecrets;
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
}
