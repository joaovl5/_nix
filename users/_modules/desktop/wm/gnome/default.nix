{
  nx = {pkgs, ...}: {
    # meant only as a fallback DE
    services = {
      desktopManager.gnome.enable = true;
      gnome = {
        core-apps.enable = false;
        core-developer-tools.enable = false;
        games.enable = false;
        gcr-ssh-agent.enable = false;
      };
    };
    environment.gnome.excludePackages = with pkgs; [gnome-tour gnome-user-docs];
  };
}
