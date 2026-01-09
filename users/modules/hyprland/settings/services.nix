{...}: {
  ## WIP
  # easyeffects
  # notif
  # blueman applet
  # clipboard mgmt
  exec-once = [
    "systemctl --user restart dbus"
    "systemctl --user restart xdg-desktop-portal"
    "systemctl --user restart xdg-desktop-portal-hyprland"
    "systemctl --user restart ironbar"
  ];
}
