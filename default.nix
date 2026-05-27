let
  inputs = (import ./inputs.nix) // {inherit self;};
  globals = import ./globals;
  outputs = let
    inherit (inputs.nixpkgs) lib;
  in
    (lib.evalModules {
      modules = [(inputs.import-tree ./modules)];
      specialArgs = {
        inherit globals inputs;
        inherit (inputs) self;
      };
    }).config.flake;
  self =
    outputs
    // {
      inherit inputs outputs;
      outPath = toString ./.;
      __toString = self: self.outPath;
      _type = "flake";
    };
in
  self
