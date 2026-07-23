{
  callPackage,
  inputs,
  ...
}:
callPackage (inputs.ashrwm-src.outPath + "/package.nix") {}
