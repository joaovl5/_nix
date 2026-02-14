_: {
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
}
