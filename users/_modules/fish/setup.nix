{
  nx = {pkgs, ...}: {
    environment.shells = [pkgs.fish];
    programs.fish.enable = true;
  };

  hm = {lib, ...} @ args: {
    programs.fish = {
      enable = true;
      shellInit = ''
        ${lib.readFile ./src/container_safe_vars.fish}
        ${lib.readFile ./src/vars.fish}
        ${import ./secrets.nix args}
      '';
      interactiveShellInit = ''
        ${lib.readFile ./src/container_safe_functions.fish}
        ${lib.readFile ./src/functions.fish}
        bind ctrl-e __yazi_zellij_ctrl_e
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
