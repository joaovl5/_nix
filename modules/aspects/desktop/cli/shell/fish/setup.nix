{lav, ...}: {
  den.aspects.cli.homeManager = {lib, ...} @ args: {
    programs.fish = {
      enable = true;
      shellInit = ''
        ${lib.readFile ./src/vars.fish}
        ${lav.cli.shell.fish.secrets args}
      '';
      interactiveShellInit = ''
        ${lib.readFile ./src/functions.fish}
        bind ctrl-e __yazi_zellij_ctrl_e
        source $HOME/.config/television/shell/integration.fish
      '';
    };

    # enable fish integrations w/ other apps/services
    programs = {
      # keep-sorted start
      eza.enableFishIntegration = true;
      fzf.enableFishIntegration = true;
      ghostty.enableFishIntegration = true;
      kitty.shellIntegration.enableFishIntegration = true;
      lazygit.enableFishIntegration = true;
      nix-index.enableFishIntegration = true;
      starship.enableFishIntegration = true;
      zoxide.enableFishIntegration = true;
      # keep-sorted end
    };
  };
  den.aspects.cli.nixos = {pkgs, ...}: {
    environment.shells = [pkgs.fish];
    programs.fish.enable = true;
  };
}
