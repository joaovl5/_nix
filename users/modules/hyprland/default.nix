let
  get_hypr_pkgs = {
    inputs,
    system,
    ...
  }:
    inputs.hyprland.packages.${system};
in {
  nx = {
    inputs,
    lib,
    pkgs,
    ...
  } @ args: let
    hyprland_pkgs = get_hypr_pkgs args;
  in {
    # programs.hyprland = {
    #   enable = true;
    #   package = hyprland_pkg;
    #   portalPackage = inputs.unstable.xdg-desktop-portal-gnome;
    #
    #   withUWSM = false;
    #   systemd.setPath.enable = true;
    # };
    #

    programs.hyprland = {
      enable = true;
      package = hyprland_pkgs.hyprland;
      portalPackage = hyprland_pkgs.xdg-desktop-portal-hyprland;
      withUWSM = true;
    };

    # xdg.icons.enable = true;
    # xdg.menus.enable = true;
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = with pkgs; [
        hyprland_pkgs.xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
      ];
      config = {
        common.default = ["gtk"];
        hyprland = {
          default = ["hyprland" "gtk" "gnome"];
          # "org.freedesktop.portal.FileChooser" = ["kde"];
          # "org.freedesktop.portal.OpenURI" = ["kde"];
        };
      };
    };

    systemd.user.services.ironbar = {
      enable = true;
      path = [pkgs.ironbar];
      description = "Ironbar unit";
      # hyprland target is provided by home-manager
      # wantedBy = ["hyprland-session.target"];
      after = ["dbus.service"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.ironbar}/bin/ironbar";
      };
    };
  };

  hm = {
    inputs,
    system,
    pkgs,
    lib,
    ...
  } @ args: let
    hyprland_pkgs = get_hypr_pkgs args;
  in {
    # write ~/.wayland-session for usage by display-manager later
    home.file.".wayland-session" = {
      source = pkgs.writeScript "init-session" ''
        if uwsm check may-start; then
            exec uwsm start hyprland.desktop
        fi
      '';
      executable = true;
    };

    systemd.user.targets.hyprland-session.Unit.Wants = [
      "xdg-desktop-autostart.target"
    ];
    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false;
      xwayland.enable = true;
      package = null;
      portalPackage = null;
      settings = import ./settings args;
    };

    services.swaync = {
      enable = true;
      # settings = {};
    };
    services.swayosd = {
      enable = true;
    };

    xdg.configFile."electron-flags.conf".text = ''
      --enable-features=UseOzonePlatform
      --ozone-platform=wayland
    '';
    xdg = {
      autostart.enable = lib.mkForce true;
      mime.enable = true;
      # portal = {
      #   enable = true;
      #   xdgOpenUsePortal = true;
      #   extraPortals = with pkgs; [
      #     xdg-desktop-portal-gtk
      #     portal_pkg
      #   ];
      #   config = {
      #     common = {
      #       # use xdg-desktop-portal-gtk for every portal interface...
      #       default = [
      #         "gnome"
      #         "gtk"
      #       ];
      #     };
      #   };
      # };
    };
  };
}
