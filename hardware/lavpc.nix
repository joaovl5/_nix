{
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.my_nix;
in {
  imports = [
    ./modules/pipewire.nix
    ./modules/grub.nix
    ./disko/lavpc.nix
    inputs.nixpkgs.nixosModules.notDetected
  ];

  my_nix.hostname = "lavpc";
  my_nix.username = "lav";
  my_nix.email = "vieiraleao2005+lavpc@gmail.com";
  my_nix.name = "João Pedro";

  time.timeZone = cfg.timezone;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  # replace here w/ output from generate-cfg

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 12;
}
