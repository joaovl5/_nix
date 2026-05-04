{
  hm = {pkgs, ...}: let
    pkg = pkgs.eww;
  in {
    hybrid-links.links.eww = {
      from = ./config;
      to = "~/.config/eww";
    };

    programs.eww = {
      enable = true;
    };

    home.packages = [
      pkg
    ];
  };
}
