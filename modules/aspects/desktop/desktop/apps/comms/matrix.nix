_: {
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      cinny-desktop
    ];
  };
}
