{lib, ...} @ args:
lib.mkMerge [
  (import ./env.nix args)
  (import ./services.nix args)
  (import ./monitors.nix args)
  (import ./keybinds.nix args)
  (import ./rules.nix args)
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
      # todo use cfg
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
]
