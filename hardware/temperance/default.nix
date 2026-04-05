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
      hostname = "temperance";
      username = "temperance";
      email = "vieiraleao2005+temperance@gmail.com";
      name = "Temperance";
      is_server = true;
    };
    luks = {
      ssh = {
        enable = true;
      };
    };
  };

  time.timeZone = cfg.timezone;

  networking = {
    defaultGateway = {
      address = "172.31.1.1";
      interface = "enp1s0";
    };
    interfaces = {
      enp1s0 = {
        ipv4 = {
          addresses = [
            {
              address = "89.167.107.74";
              prefixLength = 32;
            }
          ];
          routes = [
            {
              address = "172.31.1.1";
              prefixLength = 32;
            }
          ];
        };
      };
    };
    useDHCP = false;
    usePredictableInterfaceNames = true;
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
  };

  nix.settings.max-jobs = lib.mkDefault 6;
}
