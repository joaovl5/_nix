{den, ...}: {
  den.aspects.hardware-tyrant = {
    includes = [
      den.aspects.base-boot-grub
      den.aspects.hardware-facter
      den.aspects.hardware-luks
    ];

    nixos = {
      lib,
      config,
      pkgs,
      ...
    }: let
      cfg = config.my.nix;
    in {
      imports = [./tyrant/_disko.nix];

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

      nix.settings.max-jobs = lib.mkDefault 6;
    };
  };
}
