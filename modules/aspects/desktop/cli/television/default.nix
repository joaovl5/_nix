_: {
  den.aspects.cli.homeManager = {pkgs, ...}: {
    hybrid-links.links.television = {
      from = ./config;
      to = "~/.config/television";
    };
    home.packages = [pkgs.television];
    shell-abbrs = {
      # television/navigation commands
      # `/` -> picker
      # `=` -> action
      # `^` -> info
      "/" = "tv channels";
      "/f" = "tv files";
      "/d" = "tv dirs";
      "=" = "cd (tv dirs)";
      "=h" = "prevd";
      "=l" = "nextd";
      "=k" = "pushd";
      "=j" = "popd";
      "^s" = "dirs";
      "^h" = "dirh";
    };
  };
}
