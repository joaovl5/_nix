{
  globals,
  lib,
  ...
}: {
  den.aspects.server.nixos = globals.units {inherit lib;};
}
