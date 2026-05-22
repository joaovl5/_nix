{inputs, ...}: let
  inherit (inputs) nixpkgs;

  supported_systems = ["x86_64-linux"];
  each_supported_system = f:
    nixpkgs.lib.genAttrs supported_systems (system:
      f nixpkgs.legacyPackages.${system});
in {
  devShells = each_supported_system (pkgs: rec {
    main = pkgs.mkShell {
      packages = [
      ];

      shellHook = ''

      '';
    };

    default = main;
  });
}
