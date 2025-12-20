{
  primary_device,
  secondary_device,
  ...
}: {
  disko.devices = {
    disk = {
      primary = {
        device = primary_device;
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
            main = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "btrfs";
                extraArgs = ["-f"]; # override existing
                # dont know if its necessary:
                # mountpoint = "/partition-root";
                swap = {
                  swapfile.size = "4G";
                  swapfile2.size = "2G";
                };
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd:10"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd:10"
                      "noatime"
                    ];
                  };
                  "@swap" = {
                    mountpoint = "/.swapvol";
                    swap = {
                      swapfile.size = "4G";
                      swapfile2.size = "2G";
                      swapfile2.path = "rel-path";
                    };
                  };
                };
              };
            };
          };
        };
      };

      secondary = {
        device = secondary_device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            other = {
              size = "100%";
              content = {
                type = "filesystem4";
                format = "ext4";
                mountpoint = "/secondary";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };
    };
  };
}
