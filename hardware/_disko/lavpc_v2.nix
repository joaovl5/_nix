{
  dev_1, # nvme ssd
  dev_2, # sata ssd
  dev_3, # sata hdd
  ...
}: let
  inherit (import ../../_lib/disko.nix) efi luks btrfs;
  inherit (btrfs) subvolume swap;
in {
  disko.devices.disk.primary = {
    device = dev_1;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        esp = efi {};
        luks_p1 = luks {name = "p1";} {
          type = "btrfs";
          subvolumes = {
            "@root" = subvolume {mp = "/";};
            "@nix" = subvolume {mp = "/nix";};
            "@swap" = swap {sz = "30G";};
          };
        };
      };
    };
  };
  disko.devices.disk.secondary = {
    device = dev_2;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        luks_p2 = luks {name = "p2";} {
          type = "btrfs";
          subvolumes = {
            "@home" = subvolume {mp = "/home";};
            "@logs" = subvolume {mp = "/var/logs";};
            "@cache" = subvolume {mp = "/var/cache";};
          };
        };
      };
    };
  };
  disko.devices.disk.tertiary = {
    device = dev_3;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        luks_p3 = luks {name = "p3";} {
          type = "btrfs";
          subvolumes = {
            "@snapshots" = subvolume {mp = "/.snapshots";};
            "@cold" = subvolume {mp = "/.cold";};
          };
        };
      };
    };
  };
}
