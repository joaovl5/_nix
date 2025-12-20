{...}: {
  disko.devices = {
    disk = {
      vda = {
        device = "/dev/vda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              type = "EF00";
              size = "100M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            swap = {
              size = "5G";
              content = {
                type = "swap";
                randomEncryption = true;
                priority = 100; # prefer encrypting as long as we have enough space
              };
            };
            main = {
              size = "100%";
              content = {
                type = "bcachefs";
                # refers to a filesystem in the `bcachefs_filesystems` attrset below.
                filesystem = "main_bcachefs";
                label = "group_a.ssd";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };

      vdb = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdb1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "main_bcachefs";
                label = "group_a.hdd";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };
    };

    bcachefs_filesystems = {
      main_bcachefs = {
        type = "bcachefs_filesystem";
        extraFormatArgs = [
          "--compression=lz4"
          "--background_compression=lz4"
          # todo handle targets
        ];
        subvolumes = {
          "subvolumes/root" = {
            mountpoint = "/";
            mountOptions = [
              "verbose"
            ];
          };
          "subvolumes/home" = {
            mountpoint = "/home";
          };
          "subvolumes/nix" = {
            mountpoint = "/nix";
          };
        };
      };
    };
  };
}
