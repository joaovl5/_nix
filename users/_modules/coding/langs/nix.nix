{
  hm = {pkgs, ...}: {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

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
