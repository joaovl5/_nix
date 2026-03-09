{
  nx = {
    pkgs,
    lib,
    ...
  }: let
    keyboard_name = "internalKeyboard";
    config_file = pkgs.writeText "kanata-${keyboard_name}-config.kbd" ''
      (defcfg
        process-unmapped-keys yes
        linux-continue-if-no-devs-found yes)

      ${lib.readFile ./config.kbd}
    '';
  in {
    boot.kernelModules = ["uinput"];
    hardware.uinput.enable = true;

    services.udev.extraRules = ''
      KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
    '';

    users.groups.uinput = {
      gid = lib.mkForce 989;
    };

    systemd.user.services."kanata-${keyboard_name}" = {
      enable = true;
      description = "Kanata keyboard remapper for ${keyboard_name}";
      wantedBy = ["default.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kanata}/bin/kanata --cfg ${config_file}";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
