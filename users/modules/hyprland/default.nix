{
  nx = {
    lib,
    pkgs,
    ...
  } @ args: let
    hyprland_pkg = pkgs.hyprland;
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
      package = hyprland_pkg;
      portalPackage = null;
      withUWSM = true;
    };

    # xdg.icons.enable = true;
    # xdg.menus.enable = true;
    # xdg.portal = {
    #   enable = true;
    #   xdgOpenUsePortal = true;
    #   extraPortals = with pkgs; [
    #     xdg-desktop-portal-gtk
    #   ];
    #   config = {
    #     common.default = ["gtk"];
    #     hyprland = {
    #       default = [
    #         "hyprland"
    #         "gtk"
    #       ];
    #     };
    #   };
    # };

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
    hyprland_pkg = pkgs.hyprland;
  in {
    # write ~/.wayland-session for usage by display-manager later
    home.file.".wayland-session" = {
      source = pkgs.writeScript "hyprland-wayland-session" ''
        ${hyprland_pkg}/bin/start-hyprland
      '';
      executable = true;
    };

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
      portal = {
        enable = lib.mkForce true;
        xdgOpenUsePortal = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
        ];
        config = {
          common = {
            # use xdg-desktop-portal-gtk for every portal interface...
            default = [
              "hyprland"
              "gtk"
            ];
          };
        };
      };
    };
  };
}
