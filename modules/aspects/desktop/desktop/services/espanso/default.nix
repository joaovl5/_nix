_: {
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    imports = [
    ];

    services.espanso = {
      enable = true;
      waylandSupport = true;
      package = pkgs.espanso-wayland;
    };
  };
}
