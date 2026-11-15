_: {
  den.aspects.coding.homeManager = {
    inputs,
    pkgs,
    ...
  }: {
    home.packages = let
      fenix = inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system};
    in
      [
        (
          fenix.complete.withComponents [
            "cargo"
            "clippy"
            "rust-src"
            "rustc"
            "rustfmt"
          ]
        )
        fenix.rust-analyzer
      ]
      ++ (with pkgs; [
        # adding some stuff so i can do `cargo install`
        pkg-config
        openssl
      ]);
  };
}
