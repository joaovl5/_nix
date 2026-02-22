{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      # lsp
      nixd
      nil
      # linter
      statix
      deadnix
      # formatter
      alejandra
    ];
  };
}
