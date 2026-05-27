_: {
  den.aspects.coding.homeManager = {
    inputs,
    pkgs,
    ...
  }: {
    home.packages = with pkgs; [
      (
        fenix.complete.withComponents [
          "cargo"
          "clippy"
          "rust-src"
          "rustc"
          "rustfmt"
        ]
      )
      rust-analyzer-nightly
    ];
  };
}
