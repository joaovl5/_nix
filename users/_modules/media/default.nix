{
  nx = _: {
    services.flatpak.packages = [
      "com.stremio.Stremio" # nixpkgs stremio is currently broken
    ];
  };

  hm = _: {
  };
}
