let
  anyrun_pkg_name = "anyrun";
in {
  nx = {pkgs, ...}: let
    anyrun_pkg = pkgs.${anyrun_pkg_name};
  in {
    systemd.user.services.anyrun-daemon = {
      enable = true;
      path = [anyrun_pkg];
      description = "Ironbar unit";
      after = ["dbus.service"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${anyrun_pkg}/bin/anyrun daemon";
      };
    };
  };
  hm = {pkgs, ...}: let
    anyrun_pkg = pkgs.${anyrun_pkg_name};
  in {
    hybrid-links.links.anyrun = {
      from = ./config;
      to = "~/.config/anyrun";
    };
    home.packages = [
      anyrun_pkg
    ];
  };
}
