{
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
    + "${_jq} '.float / ${toString zoom_factor_out} | if . < 1 then 1 else . end)'";

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
        ## Menus - todo
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
  ]
