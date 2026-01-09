{
  hm = {lib, ...}: {
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        ${lib.readFile ./src/vars.fish}
        ${lib.readFile ./src/functions.fish}
      '';
    };

    # enable fish integrations w/ other apps/services
    programs = {
      zoxide.enableFishIntegration = true;
      eza.enableFishIntegration = true;
      fzf.enableFishIntegration = true;
      nix-index.enableFishIntegration = true;
      starship.enableFishIntegration = true;
      lazygit.enableFishIntegration = true;
      ghostty.enableFishIntegration = true;
      kitty.shellIntegration.enableFishIntegration = true;
    };
    services = {
      ssh-agent.enableFishIntegration = true;
    };
  };
}
