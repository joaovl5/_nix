{
  nx = {pkgs, ...}: {
    services.flatpak.packages = [
      "com.stremio.Stremio" # nixpkgs stremio is currently broken
    ];
  };

  hm = {pkgs, ...}: {
  };
}
