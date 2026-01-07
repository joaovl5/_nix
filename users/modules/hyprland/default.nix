let
  get_hyprland = {
    inputs,
    system,
    ...
  }:
    inputs.hyprland.packages.${system}.hyprland;
in {
  nx = {
    inputs,
    lib,
    pkgs,
    ...
  } @ args: let
    hyprland_pkg = get_hyprland args;
  in {
    programs.hyprland = {
      enable = true;
      package = hyprland_pkg;
      portalPackage = pkgs.xdg-desktop-portal-gnome;

      withUWSM = false;
      systemd.setPath.enable = true;
    };

    systemd.user.services.ironbar = {
      enable = true;
      path = [pkgs.ironbar];
      description = "Ironbar unit";
      # hyprland target is provided by home-manager
      wantedBy = ["hyprland-session.target"];
      after = ["dbus.service"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.ironbar}/bin/ironbar";
      };
    };

    xdg = {
      autostart.enable = lib.mkForce false;
      menus.enable = lib.mkDefault true;
      mime.enable = lib.mkDefault true;
      icons.enable = lib.mkDefault true;
      portal = {
        enable = true;
        # sets environment variable NIXOS_XDG_OPEN_USE_PORTAL to 1
        xdgOpenUsePortal = true;
        # ls /run/current-system/sw/share/xdg-desktop-portal/portals/
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk # for provides file picker / OpenURI
          xdg-desktop-portal-gnome # for screensharing
        ];
        config = {
          common = {
            # use xdg-desktop-portal-gtk for every portal interface...
            default = [
              "gtk"
              "gnome"
            ];
          };
        };
      };
    };
  };

  hm = {
    inputs,
    system,
    pkgs,
    ...
  } @ args: let
    hyprland_pkg = get_hyprland args;
  in {
    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = true; # allows using `hyprland-session.target`
      xwayland.enable = true;
      # portalPackage = pkgs.xdg-desktop-portal-gnome;
      package = hyprland_pkg;
      settings = import ./settings args;
    };

    services.swaync = {
      enable = true;
      # settings = {};
    };
    services.swayosd = {
      enable = true;
    };
  };
}
