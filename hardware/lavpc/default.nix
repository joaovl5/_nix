{
  lib,
  config,
  modulesPath,
  ...
}: let
  cfg = config.my.nix;
in {
  imports = [
    ../_modules/grub.nix
    ../_modules/nvidia.nix
    ./disko.nix
    "${modulesPath}/installer/scan/not-detected.nix"
  ];
  config = {
    my.nix = {
      hostname = "lavpc";
      username = "lav";
      email = "vieiraleao2005+lavpc@gmail.com";
      name = "João Pedro";

      # TODO: ^0
      monitor_layout = {
        "DP-4" = {
          primary = true;
          resolution = "3840x2160";
          refresh = "240.08";
          scaling = "1.333333";
        };
        "HDMI-A-2" = {
          primary = false;
          transform = "90";
        };
      };
    };

    my.nvidia.enable = true;

    time.timeZone = cfg.timezone;
    hardware = {
      graphics.enable = true;
      bluetooth.enable = true;
      cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
    services.blueman.enable = true;

    networking.useDHCP = lib.mkDefault true;
    networking.usePredictableInterfaceNames = lib.mkDefault true;
    boot = {
      initrd.availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
      initrd.kernelModules = [];
      kernelModules = ["kvm-amd"];
      extraModulePackages = [];
    };
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    nix.settings.max-jobs = lib.mkDefault 12;
  };
}
