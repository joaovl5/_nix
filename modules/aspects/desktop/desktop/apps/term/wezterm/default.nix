_: {
  den.aspects.desktop.homeManager = {
    hybrid-links.links.wezterm = {
      from = ./config/lua;
      to = "~/.config/wezterm";
    };

    programs.wezterm = {
      enable = true;
    };
  };
}
