_: {
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    services.easyeffects.enable = true;

    home.packages = with pkgs; [
      qpwgraph
      coppwr
    ];
  };
}
