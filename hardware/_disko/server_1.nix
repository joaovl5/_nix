{primary_device, ...}: let
  inherit (import ../../_lib/disko) mbr luks btrfs;
  inherit (btrfs) subvolume swap;
in {
  disko.devices.disk.primary = {
    device = primary_device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        bios = mbr {};
        boot = {
          size = "1G";
          content = {
            mountpoint = "/boot";
            type = "filesystem";
            format = "vfat";
          };
        };
        luks = luks {name = "p1";} {
          type = "btrfs";
          subvolumes = {
            "@root" = subvolume {mp = "/";};
            "@nix" = subvolume {mp = "/nix";};
            "@swap" = swap {sz = "32G";};
            "@home" = subvolume {mp = "/home";};
            "@logs" = subvolume {mp = "/var/logs";};
            "@cache" = subvolume {mp = "/var/cache";};
          };
        };
      };
    };
  };
}
