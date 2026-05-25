{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      sqlit-tui
      dbeaver-bin
    ];
  };
}
