_: {
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    hybrid-links.links.niri = {
      from = ./config;
      to = "~/.config/niri";
    };

    home.packages = with pkgs; [
      xwayland-satellite
    ];
  };
  den.aspects.desktop.nixos = {pkgs, ...}: {
    programs.niri = {
      enable = true;
      package = pkgs.niri;
    };
  };
}
