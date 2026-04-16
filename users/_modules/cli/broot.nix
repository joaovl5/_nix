{
  hm = _: {
    programs.broot = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      settings = {
        modal = true;
        syntax_theme = "github";
      };
    };
  };
}
