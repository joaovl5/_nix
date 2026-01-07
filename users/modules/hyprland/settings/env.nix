{...}: {
  env = [
    # Wayland/System
    "CLUTTER_BACKEND,wayland"
    "GDK_BACKEND,wayland,x11"
    "QT_QPA_PLATFORM,wayland;xcb"
    "QT_QPA_PLATFORMTHEME,qt5ct"
    "QT_QPA_PLATFORMTHEME,qt6ct"
    "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
    "XDG_CURRENT_DESKTOP,Hyprland"
    "XDG_SESSION_DESKTOP,Hyprland"
    "XDG_SESSION_TYPE,Hyprland"
    ## Monitor Scaling
    "GDK_SCALE,1.333333"
    "QT_SCALE_FACTOR,1"
    "QT_AUTO_SCREEN_SCALE_FACTOR,1"
    # Apps
    ## Defaults
    "TERMINAL, ghostty"
    "EDITOR, nvim"
    ## Firefox
    "MOZ_ENABLE_WAYLAND,1"
    ## Electron
    "ELECTRON_OZONE_PLATFORM_HINT, auto"
    ## Hyprland
    "HYPRLAND_LOG_WLR=0"
    "WLR_NO_HARDWARE_CURSORS=1"

    ## Hardware
    ### NVIDIA
    "LIBVA_DRIVER_NAME, nvidia"
    "__GLX_VENDOR_LIBRARY_NAME, nvidia"
    "NVD_BACKEND,direct"
    "GBM_BACKEND,nvidia-drm"
    "__NV_PRIME_RENDER_OFFLOAD,1"
    "__VK_LAYER_NV_optimus,NVIDIA_only"
    "WLR_DRM_NO_ATOMIC,1"
    "MOZ_DISABLE_RDD_SANDBOX,1"
    "EGL_PLATFORM,wayland"
  ];

  exec-once = let
    vars = "DISPLAY I3SOCK SWAYSOCK WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland";
  in [
    "dbus-update-activation-environment ${vars}"
    "systemctl --user set-environment ${vars}"
  ];
}
