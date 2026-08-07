{
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    hybrid-links.links.fuzzel = {
      from = ./config;
      to = "~/.config/fuzzel";
    };
    home.packages = with pkgs; [fuzzel];
  };
}
