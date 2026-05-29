{inputs, ...}: let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  local_packages = import ../_packages {inherit pkgs inputs;};
  main = pkgs.mkShell {
    packages = with pkgs; [
      # keep-sorted start
      alejandra
      basedpyright
      biome
      deadnix
      fish
      jsonfmt
      just
      kdlfmt
      keep-sorted
      local_packages.rumdl
      local_packages.sane_fnlfmt
      ruff
      shfmt
      sqruff
      statix
      taplo
      yamlfmt
      # keep-sorted end
    ];
  };
in {
  flake.devShells.${system} = {
    inherit main;
    default = main;
  };
}
