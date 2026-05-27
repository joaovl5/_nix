{inputs, ...}: let
  inherit (inputs) nixpkgs;

  supported_systems = ["x86_64-linux"];
  each_supported_system = f:
    nixpkgs.lib.genAttrs supported_systems (system:
      f nixpkgs.legacyPackages.${system});
in {
  devShells = each_supported_system (pkgs: rec {
    main = pkgs.mkShell {
      packages = with pkgs; [
        # things
        keep-sorted
        inputs.self.packages.${system}.rumdl

        # le nixes
        alejandra
        deadnix
        statix

        # snakes
        ruff
        basedpyright

        # shells and stuff
        fish
        shfmt
        just

        # things
        taplo
        yamlfmt
        jsonfmt
        kdlfmt
        sqruff

        # js
        biome

        # le lisps
        inputs.self.packages.${system}.sane_fnlfmt
      ];

      shellHook = ''

      '';
    };

    default = main;
  });
}
