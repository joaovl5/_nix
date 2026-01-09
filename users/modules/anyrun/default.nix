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
  hm = {
    pkgs,
    lib,
    ...
  }: let
    anyrun_pkg = pkgs.${anyrun_pkg_name};
  in {
    programs.anyrun = {
      enable = true;
      package = anyrun_pkg;
      extraCss = lib.readFile ./style.css;
      config = {
        plugins = [
          "${anyrun_pkg}/lib/libapplications.so"
          "${anyrun_pkg}/lib/libshell.so"
          "${anyrun_pkg}/lib/libwebsearch.so"
          "${anyrun_pkg}/lib/libkidex.so"
          "${anyrun_pkg}/lib/libsymbols.so"
          "${anyrun_pkg}/lib/libtranslate.so"
        ];
        x = {fraction = 0.5;};
        y = {fraction = 0.02;};
        width = {absolute = 800;};
        height = {absolute = 1;};
      };
    };
  };
}
