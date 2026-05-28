_: {
  den.aspects.coding.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      sqlit-tui
      dbeaver-bin
    ];
  };
}
