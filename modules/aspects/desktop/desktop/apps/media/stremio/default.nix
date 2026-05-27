_: {
  den.aspects.desktop.homeManager = {
  };
  den.aspects.desktop.nixos = {
    services.flatpak.packages = [
      "com.stremio.Stremio" # nixpkgs stremio is currently broken
    ];
  };
}
