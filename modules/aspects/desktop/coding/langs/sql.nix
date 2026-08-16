_: {
  den.aspects.coding.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      # FIXME: fix sqlit-tui build-error later
      # sqlit-tui
      dbeaver-bin
    ];
  };
}
