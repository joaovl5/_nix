let
  params = {primary_device = "/dev/sda";};
  inherit (import ../../../../lib/disko) mbr luks btrfs;
  inherit (btrfs) subvolume swap;
  disko_config = {
    disko.devices.disk.primary = {
      device = params.primary_device;
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
  };
in
  _: (disko_config
    // {
      boot.loader.grub.enable = false;
      boot.loader.limine = {
        enable = true;
        biosDevice = params.primary_device;
        force = true;
        efiSupport = false;
      };
    })
