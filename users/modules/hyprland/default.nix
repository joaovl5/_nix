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
    #
    programs.hyprland = {
      enable = true;
      package = hyprland_pkg;
      portalPackage = pkgs.xdg-desktop-portal-wlr;
      withUWSM = true;
    };

    environment.variables = {
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "Hyprland";
      ## qt
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_QPA_PLATFORMTHEME = "qt5ct;qt6ct";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      ## gtk
      GDK_BACKEND = "wayland,x11";
      ## sdl
      SDL_VIDEODRIVER = "wayland";
      ## etc
      CLUTTER_BACKEND = "wayland";
      ## Monitor Scaling
      GDK_SCALE = "1.333333";
      QT_SCALE_FACTOR = "1";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      # Apps
      ## Defaults
      TERMINAL = "ghostty";
      EDITOR = "nvim";
      ## Firefox
      MOZ_ENABLE_WAYLAND = "1";
      ## Electron
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      ## Hyprland
      HYPRLAND_LOG_WLR = "0";
      HYPRLAND_TRACE = "1";
      WLR_NO_HARDWARE_CURSORS = "1";

      ## Hardware
      ### NVIDIA
      LIBVA_DRIVER_NAME = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      NVD_BACKEND = "direct";
      GBM_BACKEND = "nvidia-drm";
      __NV_PRIME_RENDER_OFFLOAD = "1";
      __VK_LAYER_NV_optimus = "NVIDIA_only";
      WLR_DRM_NO_ATOMIC = "1";
      MOZ_DISABLE_RDD_SANDBOX = "1";
      EGL_PLATFORM = "wayland";
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
      portalPackage = pkgs.xdg-desktop-portal-wlr;
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
    # xdg = {
    #   autostart.enable = lib.mkForce true;
    #   mime.enable = true;
    #   portal = {
    #     enable = lib.mkForce true;
    #     xdgOpenUsePortal = true;
    #     extraPortals = with pkgs; [
    #       xdg-desktop-portal-gnome
    #       xdg-desktop-portal-gtk
    #     ];
    #     config = {
    #       common = {
    #         default = [
    #           "gnome"
    #           "gtk"
    #         ];
    #       };
    #     };
    #   };
    # };
  };
}
