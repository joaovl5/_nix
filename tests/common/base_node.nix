{
  self,
  config,
  mylib,
  ...
}: let
  my = mylib.use config;
  o = my.options;
in {
  nixpkgs.overlays = self._channels.overlays;

  my.nix = o.def {
    hostname = "testbox";
    username = "tester";
    name = "tester";
    email = "testbox@trll.ing";
  };
}
