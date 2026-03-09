{
  nx = {lib, ...}: let
    keyboard_name = "internalKeyboard";
    devices = [
      "pci-0000:0d:00.0-usbv2-0:1:1.1-event-kbd"
      "pci-0000:0f:00.4-usbv2-0:1.1:1.1-event-kbd"
      "pci-0000:10:00.0-usbv2-0:1:1.1-event-kbd"
    ];
  in {
    boot.kernelModules = ["uinput"];
    hardware.uinput.enable = true;
    services.udev.extraRules = ''
      KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
    '';
    users.groups.uinput = {};

    # Add the Kanata service user to necessary groups
    systemd.services."kanata-${keyboard_name}".serviceConfig = {
      SupplementaryGroups = [
        "input"
        "uinput"
      ];
    };

    services.kanata = {
      enable = true;
      keyboards.${keyboard_name} = {
        devices = map (x: "/dev/input/by-path/${x}") devices;
        extraDefCfg = "process-unmapped-keys yes";
        config = lib.readFile ./config.kbd;
      };
    };
  };
}
