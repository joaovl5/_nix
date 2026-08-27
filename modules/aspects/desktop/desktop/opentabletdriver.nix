_: {
  den.aspects.desktop.nixos = _: {
    hardware.opentabletdriver.enable = true;
    hardware.uinput.enable = true;
    boot.kernelModules = ["uinput"];
  };
}
