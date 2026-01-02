# meant only as a fallback DE
{pkgs, ...}: {
  services.desktopManager.gnome.enable = true;
  services.gnome.core-apps.enable = false;
  services.gnome.core-developer-tools.enable = false;
  services.gnome.games.enable = false;
  services.gnome.gcr-ssh-agent.enable = false;
  environment.gnome.excludePackages = with pkgs; [gnome-tour gnome-user-docs];
}
