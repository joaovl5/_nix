let
  primary_device = "/dev/sda";

  inherit (import ../../_lib/disko) efi luks btrfs gpt;
  inherit (btrfs) subvolume swap;
in
  _: {
    boot.loader.grub.enable = false;
    boot.loader.limine = {
      enable = true;
      biosDevice = primary_device;
      force = true;
      efiSupport = true;
    };

    disko.devices.disk.primary = gpt primary_device {
      esp = efi {};
      luks = luks {name = "p1";} {
        type = "btrfs";
        subvolumes = {
          "@root" = subvolume {mp = "/";};
          "@nix" = subvolume {mp = "/nix";};
          "@swap" = swap {sz = "4G";};
          "@home" = subvolume {mp = "/home";};
          "@logs" = subvolume {mp = "/var/logs";};
          "@cache" = subvolume {mp = "/var/cache";};
        };
      };
    };
  }
