_: {
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    hybrid-links.links.kanata = {
      from = ./config;
      to = "~/.config/kanata";
    };

    home.packages = [pkgs.kanata];
  };
  den.aspects.desktop.nixos = {
    pkgs,
    lib,
    ...
  }: let
    keyboard_name = "internalKeyboard";
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
        ExecStart = "${pkgs.kanata}/bin/kanata --cfg %h/.config/kanata/config.kbd";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
