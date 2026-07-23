_: {
  den.aspects.desktop.homeManager = {
    lib,
    pkgs,
    ...
  }: let
    power_off_outputs = pkgs.writeShellScript "power-off-outputs" ''
      case "''${XDG_CURRENT_DESKTOP:-}" in
        *niri*) exec ${lib.getExe pkgs.niri} msg action power-off-monitors ;;
        *) exec ${lib.getExe pkgs.wlopm} --off '*' ;;
      esac
    '';
    power_on_outputs = pkgs.writeShellScript "power-on-outputs" ''
      case "''${XDG_CURRENT_DESKTOP:-}" in
        *niri*) exit 0 ;;
        *) exec ${lib.getExe pkgs.wlopm} --on '*' ;;
      esac
    '';
  in {
    services = {
      gnome-keyring.enable = true;
      swaync.enable = true;
      swayidle = {
        enable = true;
        # HACK: Work around swayidle 1.9.0 timeout-only logind bus regression.
        events."before-sleep" = "true";
        timeouts = [
          {
            timeout = 300;
            command = "${power_off_outputs}";
            resumeCommand = "${power_on_outputs}";
          }
        ];
      };
    };
  };
}
