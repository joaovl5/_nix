{
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      ungoogled-chromium
    ];
  };
}
