{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      fennel-ls
      fnlfmt
    ];
  };
}
