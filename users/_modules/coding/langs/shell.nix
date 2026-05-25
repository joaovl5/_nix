{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      fish-lsp
      shfmt
    ];
  };
}
