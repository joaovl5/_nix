{
  nx = {
    pkgs,
    lib,
    ...
  }: {
    systemd.user.services.float-checker-script = {
      enable = true;
      path = [pkgs.uv];
      serviceConfig = {
        Type = "simple";
        ExecStart =
          pkgs.writeScript
          "float_checker_script" (lib.readFile ./float_checker_script.py);
      };
    };
  };
  hm = {
    pkgs,
    inputs,
    lib,
    ...
  }: let
    inherit (lib.meta) getExe;

    # run = cmd: "${pkgs.runapp}/bin/runapp ${cmd}";
    term = ["${pkgs.ghostty}/bin/ghostty" "+new-window"];
    # explorer = run "${pkgs.thunar}/bin/Thunar";
    # screenshot = "${pkgs.hyprshot}/bin/hyprshot -m region --clipboard-only";
    _anyrun = "${pkgs.anyrun}/bin/anyrun";
    launcher.menu = [_anyrun "--plugins" "libapplications.so"];
  in {
    imports = [
      inputs.niri.homeModules.niri
    ];

    programs.niri = {
      enable = true;

      settings = let
        main = "DP-4";
        side = "HDMI-A-2";

        _w = key: output: {
          "${key}" = {
            name = key;
            open-on-output = output;
          };
        };
      in {
        gestures.hot-corners.enable = false;
        outputs = {
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
        workspaces = lib.mkMerge [
          (_w "A" main)
          (_w "B" main)
          (_w "C" main)
          (_w "D" main)
          (_w "E" main)
          (_w "F" side)
          (_w "G" side)
          (_w "H" side)
          (_w "I" side)
          (_w "J" side)
        ];
        binds = {
          "Mod+Q".action.close-window = {};
          "Mod+Shift+Slash".action.show-hotkey-overlay = {};
          "Mod+Shift+S".action.screenshot = {};

          "Mod+Return".action.spawn = term;
          "Mod+Space".action.spawn = launcher.menu;

          "Mod+H".action.focus-column-left-or-last = {};
          "Mod+L".action.focus-column-right-or-first = {};
          "Mod+J".action.focus-window-or-workspace-down = {};
          "Mod+K".action.focus-window-or-workspace-up = {};
          "Mod+B".action.center-column = {};
          "Mod+Shift+B".action.center-visible-columns = {};
          "Mod+Alt+B".action.center-window = {};
          "Mod+Ctrl+H".action.move-column-left-or-to-monitor-left = {};
          "Mod+Ctrl+J".action.move-window-down-or-to-workspace-down = {};
          "Mod+Ctrl+K".action.move-window-up-or-to-workspace-up = {};
          "Mod+Ctrl+L".action.move-column-right-or-to-monitor-right = {};
          "Mod+Shift+H".action.focus-monitor-left = {};
          "Mod+Shift+J".action.focus-workspace-down = {};
          "Mod+Shift+K".action.focus-workspace-up = {};
          "Mod+Shift+L".action.focus-monitor-right = {};
          "Mod+Alt+H".action.move-column-to-monitor-left = {};
          "Mod+Alt+J".action.move-column-to-workspace-down = {};
          "Mod+Alt+K".action.move-column-to-workspace-up = {};
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

          "Mod+1".action.focus-workspace = "A";
          "Mod+2".action.focus-workspace = "B";
          "Mod+3".action.focus-workspace = "C";
          "Mod+4".action.focus-workspace = "D";
          "Mod+5".action.focus-workspace = "E";
          "Mod+6".action.focus-workspace = "F";
          "Mod+7".action.focus-workspace = "G";
          "Mod+8".action.focus-workspace = "H";
          "Mod+9".action.focus-workspace = "I";
          "Mod+0".action.focus-workspace = "J";
          "Mod+Shift+1".action.move-column-to-workspace = "A";
          "Mod+Shift+2".action.move-column-to-workspace = "B";
          "Mod+Shift+3".action.move-column-to-workspace = "C";
          "Mod+Shift+4".action.move-column-to-workspace = "D";
          "Mod+Shift+5".action.move-column-to-workspace = "E";
          "Mod+Shift+6".action.move-column-to-workspace = "F";
          "Mod+Shift+7".action.move-column-to-workspace = "G";
          "Mod+Shift+8".action.move-column-to-workspace = "H";
          "Mod+Shift+9".action.move-column-to-workspace = "I";
          "Mod+Shift+0".action.move-column-to-workspace = "J";
        };
        input = {
          workspace-auto-back-and-forth = true;

          mouse = {
            accel-profile = "flat";
            accel-speed = 1;
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
        spawn-at-startup = [
          {sh = "systemctl start ironbar";}
          {sh = "systemctl start float-checker-script";}
        ];
        window-rules = [
          # not working properly
          # see `float-checker-script`
          # this will make all librewolf windows float, but
          # the script does the rest

          {
            matches = [
              {app-id = "librewolf";}
            ];
            open-floating = true;
            default-floating-position = {
              x = 0;
              y = 500;
              relative-to = "bottom";
            };
          }
        ];
      };
    };
  };
}
