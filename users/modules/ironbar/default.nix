let
  ironbar_pkg_name = "anyrun";
in {
  nx = {pkgs, ...}: let
    ironbar_pkg = pkgs.${ironbar_pkg_name};
  in {
    systemd.user.services.ironbar = {
      enable = true;
      path = [pkgs.ironbar];
      description = "Ironbar unit";
      # hyprland target is provided by home-manager
      # wantedBy = ["hyprland-session.target"];
      after = ["dbus.service"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.ironbar}/bin/ironbar";
      };
    };
  };
  hm = {
    pkgs,
    lib,
    ...
  } @ args: let
    # ironbar_pkg = pkgs.${ironbar_pkg_name};
    ironbar_cfg = import ./config.nix args;
  in {
    xdg.configFile."ironbar/config.json".text = builtins.toJSON ironbar_cfg;
    xdg.configFile."ironbar/style.css".source = ./style.css;
  };
}
