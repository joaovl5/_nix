{
  lib,
  config,
  inputs,
  modulesPath,
  ...
}: let
  cfg = config.my_nix;
in {
  imports = [
    ./modules/grub.nix
    ./disko/lavpc_v2.nix
    "${modulesPath}/installer/scan/not-detected.nix"
  ];

  my_nix.hostname = "lavpc";
  my_nix.username = "lav";
  my_nix.email = "vieiraleao2005+lavpc@gmail.com";
  my_nix.name = "João Pedro";
  my_nix.flake_location = "/home/lav/my_nix";
  my_nix.monitor_layout = {
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

  time.timeZone = cfg.timezone;

  ## nvidia
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
  };

  ## etc

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 12;
}
