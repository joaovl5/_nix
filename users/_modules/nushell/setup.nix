{
  hm = _: {
    programs.nushell = {
      enable = true;
    };

    # integrations
    services = {
      proton-pass-agent.enableNushellIntegration = true;
      gpg-agent.enableNushellIntegration = true;
      ssh-agent.enableNushellIntegration = true;
    };
    programs = {
      intelli-shell.enableNushellIntegration = true;
      pay-respects.enableNushellIntegration = true;
      oh-my-posh.enableNushellIntegration = true;
      television.enableNushellIntegration = true;
      dircolors.enableNushellIntegration = true;
      carapace.enableNushellIntegration = true;
      keychain.enableNushellIntegration = true;
      starship.enableNushellIntegration = true;
      lazygit.enableNushellIntegration = true;
      direnv.enableNushellIntegration = true;
      zoxide.enableNushellIntegration = true;
      aliae.enableNushellIntegration = true;
      atuin.enableNushellIntegration = true;
      broot.enableNushellIntegration = true;
      vivid.enableNushellIntegration = true;
      mise.enableNushellIntegration = true;
      yazi.enableNushellIntegration = true;
      eza.enableNushellIntegration = true;
    };
  };
}
