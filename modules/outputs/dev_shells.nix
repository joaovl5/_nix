{inputs, ...}: let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  main = pkgs.mkShell {
    packages = with pkgs; [
      keep-sorted
      inputs.self.packages.${system}.rumdl
      alejandra
      deadnix
      statix
      ruff
      basedpyright
      fish
      shfmt
      just
      taplo
      yamlfmt
      jsonfmt
      kdlfmt
      sqruff
      biome
      inputs.self.packages.${system}.sane_fnlfmt
    ];
  };
in {
  flake.devShells.${system} = {
    inherit main;
    default = main;
  };
}
