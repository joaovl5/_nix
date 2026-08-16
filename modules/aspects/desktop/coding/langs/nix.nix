_: {
  den.aspects.coding.homeManager = {
    pkgs,
    inputs,
    system,
    ...
  }: {
    home.packages = with pkgs; [
      # lsp
      nixd
      nil
      # linter
      statix
      deadnix
      # formatter
      alejandra

      inputs.devenv.packages.${system}.default
    ];
  };
}
