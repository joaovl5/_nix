let
  inputs = import ./inputs.nix;
  globals = import ./globals;
  repo_root = toString ./.;
  flake_file_config =
    inputs.nixpkgs.lib.evalModules {
      modules = [
        inputs.flake-file.flakeModules.unflake
        ./flake-file.nix
      ];
      specialArgs = {inherit inputs;};
    };
in
  inputs.withInputs (inputs: let
    outputs = inputs.fup.lib.mkFlake (import ./outputs {inherit globals inputs;});
  in
    outputs
    // {
      supportedSystems = ["x86_64-linux"];
      outPath = repo_root;
      __toString = self: self.outPath;
    })
  // {
    flake-file = flake_file_config.config.flake-file;
  }
