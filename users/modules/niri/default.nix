{
  hm = {
    pkgs,
    inputs,
    lib,
    ...
  }: let
    inherit (lib.meta) getExe;

    run = cmd: "${pkgs.runapp}/bin/runapp ${cmd}";
    term = ["${pkgs.ghostty}/bin/ghostty" "+new-window"];
    explorer = run "${pkgs.thunar}/bin/Thunar";
    # screenshot = "${pkgs.hyprshot}/bin/hyprshot -m region --clipboard-only";
    _anyrun = "${pkgs.anyrun}/bin/anyrun";
    launcher.menu = [_anyrun "--plugins" "libapplications.so"];
  in {
    imports = [
      inputs.niri.homeModules.niri
    ];

    programs.niri = {
      enable = true;

      settings = {
        gestures.hot-corners.enable = false;
        workspaces = {
          "01" = {name = "01";};
          "02" = {name = "02";};
          "03" = {name = "03";};
          "04" = {name = "04";};
          "05" = {name = "05";};
          "06" = {name = "06";};
          "07" = {name = "07";};
          "08" = {name = "08";};
          "09" = {name = "09";};
          "10" = {name = "10";};
        };
        binds = {
          "Mod+Q".action.close-window = {};
          "Mod+Shift+Slash".action.show-hotkey-overlay = {};
          "Mod+Shift+S".action.screenshot = {};

          "Mod+Return".action.spawn = term;
          "Mod+Space".action.spawn = launcher.menu;

          "Mod+H".action.focus-column-left = {};
          "Mod+L".action.focus-column-right = {};
          "Mod+J".action.focus-window-or-workspace-down = {};
          "Mod+K".action.focus-window-or-workspace-up = {};
          "Mod+B".action.center-column = {};
          "Mod+Shift+B".action.center-visible-columns = {};
          "Mod+Alt+B".action.center-window = {};
          "Mod+Ctrl+H".action.move-column-left = {};
          "Mod+Ctrl+J".action.move-window-down = {};
          "Mod+Ctrl+K".action.move-window-up = {};
          "Mod+Ctrl+L".action.move-column-right = {};
          "Mod+Shift+H".action.focus-monitor-left = {};
          "Mod+Shift+J".action.focus-monitor-down = {};
          "Mod+Shift+K".action.focus-monitor-up = {};
          "Mod+Shift+L".action.focus-monitor-right = {};
          "Mod+Alt+H".action.move-column-to-monitor-left = {};
          "Mod+Alt+J".action.move-column-to-monitor-down = {};
          "Mod+Alt+K".action.move-column-to-monitor-up = {};
          "Mod+Alt+L".action.move-column-to-monitor-right = {};

          "Mod+Y".action.focus-column-first = {};
          "Mod+O".action.focus-column-last = {};
          "Mod+Ctrl+Y".action.move-column-to-first = {};
          "Mod+Ctrl+O".action.move-column-to-last = {};

          "Mod+BracketLeft".action.consume-or-expel-window-left = {};
          "Mod+BracketRight".action.consume-or-expel-window-right = {};
          "Mod+Comma".action.consume-window-into-column = {};
          "Mod+Period".action.expel-window-from-column = {};

          "Mod+Minus".action.set-column-width = "-10%";
          "Mod+Equal".action.set-column-width = "+10%";
          "Mod+Backslash".action.switch-preset-column-width = {};
          "Mod+Shift+Minus".action.set-window-height = "-10%";
          "Mod+Shift+Equal".action.set-window-height = "+10%";

          "Mod+Shift+T".action.toggle-column-tabbed-display = {};
          "Mod+Shift+F".action.toggle-window-floating = {};
          "Mod+F".action.maximize-column = {};
          "Mod+Alt+F".action.fullscreen-window = {};

          "Mod+Shift+I".action.move-workspace-up = {};
          "Mod+Shift+U".action.move-workspace-down = {};

          "Mod+Tab".action.toggle-overview = {};

          "Mod+1".action.focus-workspace = "01";
          "Mod+2".action.focus-workspace = "02";
          "Mod+3".action.focus-workspace = "03";
          "Mod+4".action.focus-workspace = "04";
          "Mod+5".action.focus-workspace = "05";
          "Mod+6".action.focus-workspace = "06";
          "Mod+7".action.focus-workspace = "07";
          "Mod+8".action.focus-workspace = "08";
          "Mod+9".action.focus-workspace = "09";
          "Mod+0".action.focus-workspace = "10";
          "Mod+Shift+1".action.move-column-to-workspace = "01";
          "Mod+Shift+2".action.move-column-to-workspace = "02";
          "Mod+Shift+3".action.move-column-to-workspace = "03";
          "Mod+Shift+4".action.move-column-to-workspace = "04";
          "Mod+Shift+5".action.move-column-to-workspace = "05";
          "Mod+Shift+6".action.move-column-to-workspace = "06";
          "Mod+Shift+7".action.move-column-to-workspace = "07";
          "Mod+Shift+8".action.move-column-to-workspace = "08";
          "Mod+Shift+9".action.move-column-to-workspace = "09";
          "Mod+Shift+0".action.move-column-to-workspace = "10";
        };
        outputs = let
          main = "DP-4";
          side = "HDMI-A-2";
        in {
          "${main}" = {
            focus-at-startup = true;
            scale = 1.333333;
            mode = {
              width = 3840;
              height = 2160;
              refresh = 240.08;
            };
            position = {
              x = 1080;
              y = 396;
            };
          };
          "${side}" = {
            scale = 1.0;
            transform = {rotation = 90;};
            mode = {
              width = 1920;
              height = 1080;
              refresh = 100.0;
            };
            position = {
              x = 0;
              y = 240;
            };
          };
        };
        input = {
          workspace-auto-back-and-forth = true;

          mouse = {
            accel-profile = "flat";
            accel-speed = -0.6;
          };
          touchpad = {
            dwt = true;
            dwtp = true;
          };
          keyboard = {
            xkb = {
              options = "compose:ralt";
            };
          };

          # someone said they think this causes issues with games
          # focus-follows-mouse.enable = true;
        };
        layout = {
          gaps = 10;
          always-center-single-column = true;
          preset-column-widths = [
            {proportion = 0.33333;}
            {proportion = 0.5;}
            {proportion = 0.66667;}
            {proportion = 1.0;}
          ];
          default-column-width = {
            proportion = 1.0;
          };
          border = {
            enable = true;
            width = 2;
          };
          focus-ring = {
            enable = false;
            width = 2;
          };
          shadow = {
            enable = true;
          };
        };
        debug = {
          #honor-xdg-activation-with-invalid-serial = {};
          #strict-new-window-focus-policy = {};
          #deactivate-unfocused-windows = {};
        };
        environment = {
          MOZ_ENABLE_WAYLAND = "1";
          XDG_CURRENT_DESKTOP = "niri";
          GDK_BACKEND = "wayland";
          CLUTTER_BACKEND = "wayland";
        };
        xwayland-satellite = {
          enable = true;
          path = getExe pkgs.xwayland-satellite;
        };
      };
    };
  };
}
