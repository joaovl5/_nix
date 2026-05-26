let
  base_inputs = import ./inputs.nix;
  globals = import ./globals;
  repo_root = toString ./.;

  base_outputs = inputs.fup.lib.mkFlake (import ./outputs {inherit globals inputs;});

  outputs =
    base_outputs
    // {
      supportedSystems = ["x86_64-linux"];
    };

  self =
    outputs
    // {
      inherit inputs outputs;
      outPath = repo_root;
      __toString = self: self.outPath;
      _type = "flake";
    };

  inputs = base_inputs // {inherit self;};
in
  self
