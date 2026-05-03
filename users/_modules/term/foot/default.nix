{
  hm = _: {
    hybrid-links.links.foot = {
      from = ./config;
      to = "~/.config/foot";
    };

    programs.foot = {
      enable = true;
      server.enable = true;
    };
  };
}
