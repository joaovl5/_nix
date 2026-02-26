{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.my.nix;
in {
  imports = [
    ../_modules/grub.nix
    ../_modules/facter.nix
    ../_modules/luks.nix
    ./disko.nix
  ];

  my = {
    nix = {
      hostname = "tyrant";
      username = "tyrant";
      email = "vieiraleao2005+tyrant@gmail.com";
      name = "Tyrant";
      is_server = true;
    };
    luks = {
      ssh = {
        enable = true;
      };
    };
  };

  time.timeZone = cfg.timezone;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.grub.efiSupport = false;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 6;
}
