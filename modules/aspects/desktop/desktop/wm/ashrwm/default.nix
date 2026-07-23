_: {
  den.aspects.desktop = {
    homeManager = {pkgs, ...}: {
      hybrid-links.links.ashrwm = {
        from = ./config;
        to = "~/.config/ashrwm";
      };

      home.packages = with pkgs; [
        grim
        slurp
      ];
    };

    nixos = {
      inputs,
      lib,
      pkgs,
      ...
    }: let
      local_packages = import ../../../../../_packages {inherit inputs pkgs;};
      ashrwm_init = pkgs.writeShellScript "ashrwm-init" ''
        set -eu
        ${lib.getExe pkgs.uwsm} finalize
        exec ${lib.getExe local_packages.ashrwm}
      '';
      ashrwm_session = pkgs.writeShellScript "ashrwm-session" ''
        exec ${lib.getExe pkgs.river} -c ${ashrwm_init}
      '';
      ashrwm_desktop = pkgs.writeTextFile {
        name = "ashrwm-uwsm.desktop";
        destination = "/share/wayland-sessions/ashrwm-uwsm.desktop";
        passthru.providedSessions = ["ashrwm-uwsm"];
        text = ''
          [Desktop Entry]
          Name=Ashrwm (UWSM)
          Comment=Ashrwm managed by UWSM
          Exec=${lib.getExe pkgs.uwsm} start -D ashrwm:X-NIXOS-SYSTEMD-AWARE -e -- ${ashrwm_session}
          Type=Application
          DesktopNames=ashrwm;X-NIXOS-SYSTEMD-AWARE
        '';
      };
    in {
      environment.systemPackages = [local_packages.ashrwm];

      programs.uwsm.enable = true;
      services.displayManager.sessionPackages = [ashrwm_desktop];
    };
  };
}
