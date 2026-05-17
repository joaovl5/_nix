{inputs, ...}: let
  inherit (inputs) nixpkgs;

  supported_systems = ["x86_64-linux"];
  each_supported_system = f:
    nixpkgs.lib.genAttrs supported_systems (system:
      f nixpkgs.legacyPackages.${system});
in {
  devShells = each_supported_system (pkgs: let
    jandent = pkgs.writeShellApplication {
      name = "jindt";
      runtimeInputs = [pkgs.janet];
      text = ''
        exec janet ${inputs.jandent-src.outPath}/jandent/jindt.janet "$@"
      '';
    };

    janet-lsp = pkgs.callPackage inputs.janet-lsp-src.outPath {};
  in rec {
    janet = pkgs.mkShell {
      packages = [
        pkgs.janet
        pkgs.jpm
        inputs.janet-nix.packages.${pkgs.system}.janet-nix
        janet-lsp
        jandent
      ];

      shellHook = ''
        # Localize jpm dependency paths for reproducible project shells.
        export JPM_ROOT="$PWD/.jpm"
        export JANET_TREE="$JPM_ROOT/jpm_tree"
        export JANET_LIBPATH="${pkgs.janet}/lib"
        export JANET_HEADERPATH="${pkgs.janet}/include/janet"
        export JANET_BUILDPATH="$JPM_ROOT/build"
        export JANET_PATH="$JANET_TREE/lib"
        export PATH="$PATH:$JANET_TREE/bin"
        mkdir -p "$JANET_TREE" "$JANET_BUILDPATH"
      '';
    };

    default = janet;
  });
}
