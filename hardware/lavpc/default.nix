{
  lib,
  config,
  modulesPath,
  ...
}: let
  cfg = config.my_nix;
in {
  imports = [
    ../_modules/grub.nix
    ../_disko/lavpc_v2.nix
    "${modulesPath}/installer/scan/not-detected.nix"
  ];
  my_nix = {
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

  time.timeZone = cfg.timezone;
  hardware = {
    ## nvidia
    graphics.enable = true;
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.latest;
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
    };

    ## etc

    bluetooth.enable = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
  services.xserver.videoDrivers = ["nvidia"];
  services.blueman.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;
  boot = {
    initrd.availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
    initrd.kernelModules = [];
    kernelModules = ["kvm-amd"];
    extraModulePackages = [];
  };
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 12;
}
