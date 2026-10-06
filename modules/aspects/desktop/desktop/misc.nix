{
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    home.packages = with pkgs.kdePackages; [
      marble
      okular
      kalgebra
    ];
  };
}
