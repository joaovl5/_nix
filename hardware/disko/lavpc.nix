{
  dev_1, # nvme ssd
  dev_2, # sata ssd
  dev_3, # sata hdd
  raid_type ? "raid5",
  ...
}: let
  inherit (import ../../lib/disko.nix) efi luks btrfs;
  inherit (btrfs) subvolume swap;
  btrfs_content = {
    type = "btrfs";
    extraArgs = [
      # "-f" # override
      "-d ${raid_type}"
      "/dev/mapper/p1"
      "/dev/mapper/p2"
    ];
    subvolumes = {
      "@root" = subvolume {
        mp = "/";
        opts = [];
      };
      "@nix" = subvolume {mp = "/nix";};
      "@logs" = subvolume {mp = "/var/logs";};
      "@home" = subvolume {mp = "/home";};
      "@swap" = swap {sz = "12G";};
    };
  };
in {
  # Devices will be mounted and formatted in alphabetical order, and btrfs can only mount raids
  # when all devices are present. So we define an "empty" luks device on the first disks,
  # and the actual btrfs raid on the second disk, and the name of these entries matters!

  # device mapping to lvm
  disko.devices.disk.primary = {
    device = dev_1;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        esp = efi {};
        luks_p1 = luks {name = "p1";} null;
      };
    };
  };
  disko.devices.disk.secondary = {
    device = dev_2;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        luks_p2 = luks {name = "p2";} null;
      };
    };
  };
  disko.devices.disk.tertiary = {
    device = dev_3;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        luks_p3 = luks {name = "p3";} btrfs_content;
      };
    };
  };
}
