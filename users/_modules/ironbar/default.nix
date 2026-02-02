let
  ironbar_pkg_name = "ironbar";
in {
  nx = {pkgs, ...}: let
    ironbar_pkg = pkgs.${ironbar_pkg_name};
  in {
    # service should manually be started by compositors
    systemd.user.services.ironbar = {
      enable = true;
      path = [pkgs.ironbar];
      description = "Ironbar unit";
      after = ["dbus.service"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${ironbar_pkg}/bin/ironbar";
      };
    };

    environment.systemPackages = with pkgs; [ironbar];
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
