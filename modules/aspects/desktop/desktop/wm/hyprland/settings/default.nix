{lav, ...}: {
  lav.desktop.wm.hyprland.settings = rec {
    __functor = _self: {lib, ...} @ args:
      lib.mkMerge [
        (lav.desktop.wm.hyprland.settings.env args)
        (lav.desktop.wm.hyprland.settings.services args)
        (lav.desktop.wm.hyprland.settings.monitors args)
        (lav.desktop.wm.hyprland.settings.keybinds args)
        (lav.desktop.wm.hyprland.settings.rules args)
        {
          xwayland.force_zero_scaling = true;

          general = {
            resize_on_border = false;
            allow_tearing = true;
            no_focus_fallback = true;
            layout = "dwindle";
          };

          misc = {
            # disable defaults
            force_default_wallpaper = 0;
            disable_hyprland_logo = true;
            middle_click_paste = false;
            # monitor render configs
            vfr = true;
            vrr = false;
            # inputs turn on screen
            mouse_move_enables_dpms = true;
            key_press_enables_dpms = true;
            # respect app focus requests
            focus_on_activate = true;

            initial_workspace_tracking = 0;
            animate_manual_resizes = false;
            animate_mouse_windowdragging = false;

            # new window forces fullscreen off
            # new_window_takes_over_fullscreen = 2
            # exiting window forces fullscreen off
            exit_window_retains_fullscreen = false;
            # window swallowing (ex: terminal being replaced by app opened within it)
            enable_swallow = true;
            swallow_regex = "^(kitty|ghostty)$";
          };

          debug = {
            damage_tracking = false; # avoid error spams with shaders
          };

          input = {
            # TODO: ^0 use cfg
            kb_layout = "us";
            # us intl layout, avoids deadkeys, prefers compose key
            # more info on compose keys: http://xahlee.info/kbd/keyboard_whats_alt_graph__compose__dead_key.html
            kb_variant = "altgr-intl";
            kb_options = "compose:ralt";

            repeat_rate = 30;
            repeat_delay = 300;

            numlock_by_default = false;
            left_handed = false;

            follow_mouse = false;
            sensitivity = -0.7;
            accel_profile = "flat";

            tablet.output = "current";
            tablet.left_handed = true; # flips tablet 180 flipped tablet
          };

          binds = {
            scroll_event_delay = 0;
            workspace_back_and_forth = true;
            allow_workspace_cycles = true;
            pass_mouse_when_bound = false;
            hide_special_on_workspace_change = true;
          };

          # ---------------------------
          # Layouts
          # ---------------------------
          dwindle = {
            pseudotile = false;
            preserve_split = true;
            smart_split = false;
            smart_resizing = false;
          };

          master.new_status = "master";

          # ---------------------------
          # Visual
          # ---------------------------
          general.gaps_in = 5;
          general.gaps_out = 15;
          general.gaps_workspaces = 50;
          general."col.active_border" = "rgba(0db7d4ee) rgba(00ff99ee) 45deg";
          general."col.inactive_border" = "rgba(595960aa)";
          general.border_size = 1;

          decoration = {
            rounding = 5;
            rounding_power = 20;

            blur = {
              enabled = true;
              new_optimizations = true;
              xray = true;
              special = false;
              size = 9;
              passes = 1;
              vibrancy = 1;
            };
          };

          animations = {
            enabled = true;
            bezier = [
              "emphasizedDecel, 0.05, 0.7, 0.1, 1"
              "standardDecel, 0, 0, 0, 1"
              "menu_decel, 0.1, 1, 0, 1"
              "menu_accel, 0.52, 0.03, 0.72, 0.08"
              "almostLinear,   0.5,  0.5,  0.75, 1"
              "quick,          0.15, 0,    0.1,  1"
            ];
            animation = [
              "global, 1, 10, default"
              "workspaces, 1, 1.94, almostLinear, fade"
              "workspacesIn, 1, 2.1, almostLinear, fade"
              "workspacesOut, 1, 2.94, almostLinear, fade"
              "windowsIn, 1, 3, emphasizedDecel, popin 80%"
              "windowsOut, 1, 2, emphasizedDecel, popin 90%"
              "windowsMove, 1, 3, emphasizedDecel, slide"
              "border, 1, 10, emphasizedDecel"
              "layersIn, 1, 2.7, emphasizedDecel, popin 93%"
              "layersOut, 1, 2.4, menu_accel, popin 94%"
              "fadeLayersIn, 1, 0.5, menu_decel"
              "fadeLayersOut, 1, 2.7, menu_accel"
              "fadeIn, 1, 1.73, almostLinear"
              "fadeOut, 1, 1.46, almostLinear"
              "fade, 1, 3.03, quick"
              "zoomFactor, 1, 7, quick"
            ];
          };

          cursor = {
            no_hardware_cursors = true;
            warp_on_change_workspace = true;

            zoom_factor = 1;
            zoom_rigid = false;
            hotspot_padding = 1;
          };
        }
      ];

    env = _: {
      # env = {
      #   # Wayland/System
      #   ## xdg stuff
      #   XDG_CURRENT_DESKTOP = "Hyprland";
      #   XDG_SESSION_DESKTOP = "Hyprland";
      #   XDG_SESSION_TYPE = "Hyprland";
      #   ## qt
      #   QT_QPA_PLATFORM = "wayland;xcb";
      #   QT_QPA_PLATFORMTHEME = "qt5ct;qt6ct";
      #   QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      #   ## gtk
      #   GDK_BACKEND = "wayland,x11";
      #   ## sdl
      #   SDL_VIDEODRIVER = "wayland";
      #   ## etc
      #   CLUTTER_BACKEND = "wayland";
      #   ## Monitor Scaling
      #   GDK_SCALE = "1.333333";
      #   QT_SCALE_FACTOR = "1";
      #   QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      #   # Apps
      #   ## Defaults
      #   TERMINAL = "ghostty";
      #   EDITOR = "nvim";
      #   ## Firefox
      #   MOZ_ENABLE_WAYLAND = "1";
      #   ## Electron
      #   ELECTRON_OZONE_PLATFORM_HINT = "auto";
      #   ## Hyprland
      #   HYPRLAND_LOG_WLR = "0";
      #   HYPRLAND_TRACE = "1";
      #   WLR_NO_HARDWARE_CURSORS = "1";
      #
      #   ## Hardware
      #   ### NVIDIA
      #   LIBVA_DRIVER_NAME = "nvidia";
      #   __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      #   NVD_BACKEND = "direct";
      #   GBM_BACKEND = "nvidia-drm";
      #   __NV_PRIME_RENDER_OFFLOAD = "1";
      #   __VK_LAYER_NV_optimus = "NVIDIA_only";
      #   WLR_DRM_NO_ATOMIC = "1";
      #   MOZ_DISABLE_RDD_SANDBOX = "1";
      #   EGL_PLATFORM = "wayland";
      # };
    };

    services = _: {
      ## WIP
      # easyeffects
      # notif
      # blueman applet
      # clipboard mgmt
      exec-once = [
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_TYPE=Hyprland XDG_SESSION_DESKTOP=Hyprland"
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_TYPE=Hyprland XDG_SESSION_DESKTOP=Hyprland"
        # "systemctl --user restart dbus"
        "systemctl --user restart xdg-desktop-portal"
        "systemctl --user restart xdg-desktop-portal-wlr"
        "systemctl --user restart ironbar"
        "systemctl --user restart anyrun-daemon"
      ];
    };

    monitors = _: {
      # this is lavpc-only, make conditional by hosts later
      monitor = let
        main = "DP-4";
        side = "HDMI-A-2";
      in [
        "${main},3840x2160@240.08,1080x396,1.333333"
        "${side},1920x1080@100.0,0x240,1.0"
        "${side},transform,1" # vertical
      ];
    };

    keybinds = {
      pkgs,
      lib,
      ...
    }: let
      # settings
      mod = "SUPER";
      resize_amount = "50"; # resizing windows amount in pixels;
      zoom_factor_in = 1.25;
      zoom_factor_out = 2;

      # apps
      run = cmd: "${pkgs.runapp}/bin/runapp ${cmd}";
      term = "${pkgs.ghostty}/bin/ghostty +new-window";
      explorer = run "${pkgs.thunar}/bin/Thunar";
      ## actions
      ### core
      exit_hyprland = "hyprctl dispatch exit 0";
      _hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
      lock_screen = "pidof ${_hyprlock} || ${_hyprlock} -q";
      force_kill_active = "kill $(hyprctl activewindow | grep -o 'pid: [0-9]*' | cut -d' ' -f2)";
      notif_menu = "${pkgs.swaynotificationcenter}/bin/swaync-client -t -sw";
      ### utils
      quick_term = "${pkgs.kitty}/bin/kitten quick-access-terminal";
      screenshot = "${pkgs.hyprshot}/bin/hyprshot -m region --clipboard-only";
      #### zoom
      _jq = "${pkgs.jq}/bin/jq";
      _get_zoom = "hyprctl getoption cursor:zoom_factor -j";
      _set_zoom = "hyprctl -q keyword cursor:zoom_factor";
      zoom_in =
        "${_set_zoom} $(${_get_zoom} | "
        + "${_jq} '.float * ${toString zoom_factor_in}')";
      zoom_out =
        "${_set_zoom} $(${_get_zoom} | "
        + "${_jq} '.float / ${toString zoom_factor_out} | if . < 1 then 1 else . end')";

      ### media actions
      _osd = "${pkgs.swayosd}/bin/swayosd-client";
      _audio = pkgs.writeShellScript "media_audio_actions" ''
        inc_volume() {
          if [ "$(pamixer --get-mute)" == "true" ]; then
            ${_osd} --output-volume=mute-toggle
          else
            ${_osd} --output-volume=+10 --max-volume=120
          fi
        }
        dec_volume() {
          if [ "$(pamixer --get-mute)" == "true" ]; then
            ${_osd} --output-volume=mute-toggle
            toggle_mute
          else
            ${_osd} --output-volume=-10 --max-volume=120
          fi
        }
        toggle_audio() {
          ${_osd} --output-volume=mute-toggle
        }
        toggle_mic() {
          ${_osd} --input-volume=mute-toggle
        }
        if [[ "$1" == "--inc" ]]; then
          inc_volume
        elif [[ "$1" == "--dec" ]]; then
          dec_volume
        elif [[ "$1" == "--toggle-audio" ]]; then
          toggle_audio
        elif [[ "$1" == "--toggle-mic" ]]; then
          toggle_mic
        else
          echo "Use an argument!"
        fi
      '';
      media.next = "${_osd} --playerctl=next";
      media.prev = "${_osd} --playerctl=prev";
      media.play_pause = "${_osd} --playerctl=play-pause";
      media.audio.inc = "${_audio} --inc";
      media.audio.dec = "${_audio} --dec";
      media.audio.mute_mic = "${_audio} --toggle-mic";
      media.audio.mute_audio = "${_audio} --toggle-audio";
      ### launcher actions
      _anyrun = "${pkgs.anyrun}/bin/anyrun";
      launcher.menu = "${_anyrun} --plugins libapplications.so";
      launcher.files = "${_anyrun} --plugins libkidex.so";
      launcher.search = "${_anyrun} --plugins libwebsearch.so";
      launcher.unicode = "${_anyrun} --plugins libsymbols.so";
      launcher.calc = "${_anyrun} --plugins librink.so";
      ## misc
      capslock_osd = "sleep 0.05 && ${"${_osd} --caps-lock"}";
      kc_apostrophe = "code:49"; # `
      kc_semicolon = "code:47"; # ;
    in
      lib.mkMerge [
        {
          # ---------------------------
          # Critical
          # ---------------------------
          bind = [
            "CTRL ALT, Delete, exec, ${exit_hyprland}"
            "CTRL ALT, L, exec, ${lock_screen}"

            # ---------------------------
            # Applications
            # ---------------------------
            ## Terminal
            "${mod}, Return, exec, ${term}"
            "${mod}, X, exec, ${quick_term}"
            ## File Explorer
            "${mod}, T, exec, ${explorer}"
            ## Menus
            "${mod}, SPACE, exec, ${launcher.menu}"
            "${mod}, C, exec, ${launcher.calc}"
            "${mod}, ${kc_semicolon}, exec, ${launcher.search}"
            "${mod}, ${kc_apostrophe}, exec, ${notif_menu}" # NOTIF PANEL
            # "${mod} ALT, SPACE " # POWER MENU
            # "${mod} SHIFT, W " # WALLPAPER SELECTOR

            # ---------------------------
            # Window Management
            # ---------------------------
            ## Action against current window
            "${mod}, Q, killactive" # quit
            "${mod} SHIFT, Q, exec, ${force_kill_active}" # force quit
            "${mod}, F, fullscreen, 1" # maximize focus but keep bar shown
            "${mod} ALT, F, fullscreen, 2" # actual fullscreen focus
            "${mod} SHIFT, F, togglefloating"
          ];
          ### Resizing
          binde = let
            prefix = "${mod} SHIFT";
          in [
            "${prefix}, H, resizeactive, -${resize_amount} 0"
            "${prefix}, J, resizeactive, 0 ${resize_amount}"
            "${prefix}, K, resizeactive, 0 -${resize_amount}"
            "${prefix}, L, resizeactive, ${resize_amount} 0"
          ];
        }
        {
          ## Navigation between windows/workspaces
          bind = lib.mkMerge (
            let
              # utils for hjkl binds
              ## map hjkl to hyprland direction codes
              _hjkl_dirs = {
                "H" = "l";
                "J" = "d";
                "K" = "u";
                "L" = "r";
              };
              hjkl_operation = prefix: dispatch:
                map (x: "${prefix}, ${x}, ${dispatch}, ${_hjkl_dirs.${x}}")
                (builtins.attrNames _hjkl_dirs);
              ## utils for workspaces
              _workspaces = builtins.genList (x: x + 1) 9; # make 10 workspaces
              _get_kc = wk_num: "code:${toString (9 + wk_num)}";
              wk_operation = prefix: dispatch:
                map (
                  wk_num: "${prefix}, ${_get_kc wk_num}, ${dispatch}, ${toString wk_num}"
                )
                _workspaces;
            in [
              ### Cycling windows
              [
                "${mod}, Tab, cyclenext"
                "${mod}, Tab, bringactivetotop"
              ]
              ### Moving window focus
              (hjkl_operation "${mod}" "movefocus")
              ### Moving window position
              (hjkl_operation "${mod} CTRL" "movewindow")
              # ---------------------------
              # Workspaces
              # ---------------------------
              ## Alternate workspace between monitors
              (hjkl_operation "${mod} ALT" "movecurrentworkspacetomonitor")
              ## Focus on workspaces
              ["${mod}, A, togglespecialworkspace, scratch"]
              ["${mod} SHIFT, A, movetoworkspace, special:scratch"]
              (wk_operation "${mod}" "workspace")
              ## Move to workspaces
              (wk_operation "${mod} SHIFT" "movetoworkspace")
              (wk_operation "${mod} CTRL" "movetoworkspacesilent")
              ["${mod} CTRL, A, movetoworkspacesilent, special:scratch"]
            ]
          );

          ### Mouse ops
          bindm = [
            "${mod}, mouse:272, movewindow" # move w/ mouse left
            "${mod}, mouse:273, resizewindow" # resize w/ mouse right
          ];

          # ---------------------------
          # Media
          # ---------------------------
          bindl = [
            ", XF86AudioNext, exec, ${media.next}"
            ", XF86AudioPrev, exec, ${media.prev}"
            ", XF86AudioPause, exec, ${media.play_pause}"
            ", XF86AudioPlay, exec, ${media.play_pause}"
            ", xf86AudioMicMute, exec, ${media.audio.mute_mic}"
            ", xf86audiomute, exec, ${media.audio.mute_audio}"
          ];
          bindel = [
            ", xf86audioraisevolume, exec, ${media.audio.inc}"
            ", xf86audiolowervolume, exec, ${media.audio.dec}"
          ];
        }
        {
          bind = [
            ## Screenshots
            "${mod} SHIFT, S, exec, ${screenshot}"
            ## Zoom with mod+scroll
            "${mod}, mouse_down, exec, ${zoom_in}"
            "${mod}, mouse_up, exec, ${zoom_out}"
          ];
        }
        {
          # ---------------------------
          # Etc
          # ---------------------------
          ## Capslock OSD
          bind = [
            ", CAPS_LOCK , exec, ${capslock_osd}"
          ];
        }
      ];

    rules = _: {
      windowrule = [
        # ignore maximize requests from apps
        "match:class *, suppress_event maximize"

        # xwayland fixes
        "no_focus on, match:class ^$, match:title ^$, match:xwayland 1, match:float 1, match:fullscreen 0, match:pin 0"
        "no_blur on, match:class ^()$, match:title ^()$"

        # avoid idle for fullscreen apps
        "idle_inhibit fullscreen, match:class ^(*)$"
        "idle_inhibit fullscreen, match:title ^(*)$"
        "idle_inhibit fullscreen, match:fullscreen 1"

        # tearing fixes
        "immediate on, match:title .*\.exe"
        "immediate on, match:title .*minecraft.*"
        "immediate on, match:class ^(steam_app).*"

        # center/float
        ## save
        "center on, float on, match:title ^(Save As)(.*)$"
        "center on, float on, match:title ^(.*)(wants to save)$"
        ## open
        "center on, float on, match:title ^(.*)(wants to open)$"
        "center on, float on, match:title ^(File Upload)(.*)$"
        "center on, float on, match:title ^(Open File)(.*)$"
        "center on, float on, match:title ^(Open File)(.*)$"
        "center on, float on, match:title ^(Open Folder)(.*)$"
        "float on, match:title ^(Add Folder to Workspace)(.*)$"
        "center on, float on, match:title ^(Select a File)(.*)$"
        "center on, float on, size (monitor_w*0.6) (monitor_h*0.65), match:title ^(Choose wallpaper)(.*)$"
        "float on, size (monitor_w*0.45), center on, match:class ^(pwvucontrol)$"
        "float on, size (monitor_w*0.45), center on, match:class ^(com.saivert.pwvucontrol)$"
        ## misc
        "center on, float on, match:title ^(Library)(.*)$"
        "center on, match:title (File Operation Progress)"
        "center on, match:title (Confirm to replace files)"
        "move (40) (80), match:title ^(Copying — Dolphin)$"
        "no_initial_focus on, match:class ^(plasma-changeicons)$"
        "float on, match:class ^(org.kde.polkit-kde-authentication-agent-1)$"
        "float on, match:class (xdg-desktop-portal-gtk)"
        "float on, match:class (xdg-desktop-portal-hyprland)"
        "float on, match:class (org.gnome.Calculator), match:title (Calculator)"
        "float on, opacity 0.9 0.6, match:class ^([Rr]ofi)$"
        "float on, match:class ^(eog)$"
        "float on, match:class ^(nwg-look|qt5ct|qt6ct|mpv)$"
        "float on, match:class ^(nm-applet|nm-connection-editor|blueman-manager)$"
        "float on, match:class ^(wihotspot-gui)$"
        "float on, match:class ^(gnome-system-monitor|org.gnome.SystemMonitor)$"
        "float on, match:class ^(yad)$"
        "float on, opacity 0.9 0.8, match:class ^(file-roller|org.gnome.FileRoller)$"
        "float on, match:class ^(evince)$"
        "float on, match:class ^([Bb]aobab|org.gnome.[Bb]aobab)$"
        "float on, opacity 0.9 0.8, size (monitor_w*0.6) (monitor_h*0.7), match:title (Kvantum Manager)"
        "float on, match:class ^([Ss]team)$, match:title ^((?![Ss]team).*|[Ss]team [Ss]ettings)$"
        "float on, match:class ^([Qq]alculate-gtk)$"
        "float on, opacity 0.9 0.7, size (monitor_w*0.6)"
        "float on, opacity 0.9 0.7, size (monitor_w*0.6) (monitor_h*0.7), match:class ^([Ff]erdium)$"

        # opacity-related
        "opacity 0.9 0.7, match:class ^(Brave-browser(-beta|-dev)?)$"
        "opacity 0.9 0.7, match:class ^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr)$"
        "opacity 0.9 0.6, match:class ^([Tt]horium-browser)$"
        "opacity 0.9 0.8, match:class ^([Mm]icrosoft-edge(-stable|-beta|-dev|-unstable)?)$"
        "opacity 0.9 0.8, match:class ^(google-chrome(-beta|-dev|-unstable)?)$"
        "opacity 0.94 0.86, match:class ^(chrome-.+-Default)$ # Chrome PWAs"
        "opacity 0.9 0.8, match:class ^([Tt]hunar)$"
        "opacity 0.8 0.6, match:class ^(pcmanfm-qt)$"
        "opacity 0.8 0.7, match:class ^(gedit|org.gnome.TextEditor)$"
        "opacity 0.9 0.8, match:class ^(deluge)$"
        "opacity 0.9 0.8, match:class ^(Alacritty)$"
        "opacity 0.9 0.8, match:class ^(kitty)$"
        "opacity 0.9 0.7, match:class ^(mousepad)$"
        "opacity 0.9 0.7, match:class ^(VSCodium|codium-url-handler)$"
        "opacity 0.9 0.8, match:class ^(nwg-look|qt5ct|qt6ct|yad)$"
        "opacity 1.0 1.0, match:class ^(com.obsproject.Studio)$"
        "opacity 0.9 0.7, match:class ^([Aa]udacious)$"
        "opacity 0.9 0.8, match:class ^(org.gnome.Nautilus)$"
        "opacity 0.9 0.8, match:class ^(VSCode|code-url-handler)$"
        "opacity 0.9 0.8, match:class ^(jetbrains-.+)$"
        "opacity 0.94 0.86, match:class ^([Dd]iscord|[Vv]esktop)$"
        "opacity 0.9 0.8, match:class ^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$"
        "opacity 0.94 0.86, match:class ^(gnome-disks|evince|wihotspot-gui|org.gnome.baobab)$"
        "opacity 0.8 0.7, match:class ^(app.drey.Warp)$"
        "opacity 0.9 0.8, match:class ^(seahorse)$"
        "opacity 0.82 0.75, size (monitor_w*0.7) (monitor_h*0.7), match:class ^(gnome-system-monitor|org.gnome.SystemMonitor)$"
        "opacity 0.9 0.8, match:class ^(xdg-desktop-portal-gtk)$"
        # size
        "size (monitor_w*0.7) (monitor_h*0.7), match:class ^(xdg-desktop-portal-gtk)$"
        "size (monitor_w*0.6) (monitor_h*0.7), match:class ^(qt6ct)$"
        "size (monitor_w*0.7) (monitor_h*0.7), match:class ^(evince|wihotspot-gui)$"
        "size (monitor_w*0.6) (monitor_h*0.7), match:class ^(file-roller|org.gnome.FileRoller)$"
        # ----------
        # etc
        "border_size 0, match:class ^(com.mitchellh.ghostty)$"
      ];

      layerrule = [
        "ignore_alpha 0, blur on, no_anim on, match:namespace overview"
        "xray on, match:namespace .*"
        # no anims
        "no_anim on, match:namespace walker"
        "no_anim on, match:namespace selection"
        "no_anim on, match:namespace overview"
        "no_anim on, match:namespace anyrun"
        "no_anim on, match:namespace indicator.*"
        "no_anim on, match:namespace osk"
        "no_anim on, match:namespace hyprpicker"
        "no_anim on, match:namespace gtk4-layer-shell"
      ];
    };
  };
}
