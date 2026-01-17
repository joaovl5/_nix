{...}: {
  ## WIP
  # easyeffects
  # notif
  # blueman applet
  # clipboard mgmt
  exec-once = [
    "systemctl --user restart dbus"
    "systemctl --user restart xdg-desktop-portal"
    "systemctl --user restart xdg-desktop-portal-wlr"
    "systemctl --user restart ironbar"
    "systemctl --user restart anyrun-daemon"
  ];
}
