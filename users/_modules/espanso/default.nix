{
  hm = {pkgs, ...}: {
    imports = [
      ./matches.nix
    ];

    services.espanso = {
      enable = true;
      waylandSupport = true;
      package = pkgs.espanso-wayland;
    };
  };
}
