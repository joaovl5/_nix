let
  with_inputs = import ./inputs.nix;
  globals = import ./globals;
  repo_root = toString ./.;
in
  with_inputs (inputs: let
    outputs = inputs.fup.lib.mkFlake (import ./outputs {inherit globals inputs;});
  in
    outputs
    // {
      supportedSystems = ["x86_64-linux"];
      outPath = repo_root;
      __toString = self: self.outPath;
    })
