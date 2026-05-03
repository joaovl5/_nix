{
  hm = _: {
    programs.nushell = {
      enable = true;
    };

    # integrations
    programs = {
      starship.enableNushellIntegration = true;
      lazygit.enableNushellIntegration = true;
      direnv.enableNushellIntegration = true;
      zoxide.enableNushellIntegration = true;
      yazi.enableNushellIntegration = true;
      eza.enableNushellIntegration = true;
    };
  };
}
