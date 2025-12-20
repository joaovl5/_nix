{...}: {
  disko.devices = {
    disk = {
      primary = {
        device = "/dev/vda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              type = "ESP";
              size = "1G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
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
                filesystem = "main_bcachefs";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };

      secondary = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            other = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "main_bcachefs";
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
