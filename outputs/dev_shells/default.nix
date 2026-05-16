{inputs, ...}: let
  inherit (inputs) nixpkgs;

  supported_systems = ["x86_64-linux"];
  each_supported_system = f:
    nixpkgs.lib.genAttrs supported_systems (system:
      f nixpkgs.legacyPackages.${system});
in {
  devShells = each_supported_system (pkgs: rec {
    janet = pkgs.mkShell {
      packages = [
        pkgs.janet
        pkgs.jpm
        inputs.janet-nix.packages.${pkgs.system}.janet-nix
      ];

      shellHook = ''
        # Localize jpm dependency paths for reproducible project shells.
        export JANET_PATH="$PWD/.jpm"
        export JANET_TREE="$JANET_PATH/jpm_tree"
        export JANET_LIBPATH="${pkgs.janet}/lib"
        export JANET_HEADERPATH="${pkgs.janet}/include/janet"
        export JANET_BUILDPATH="$JANET_PATH/build"
        export PATH="$PATH:$JANET_TREE/bin"
        mkdir -p "$JANET_TREE" "$JANET_BUILDPATH"
      '';
    };

    default = janet;
  });
}
