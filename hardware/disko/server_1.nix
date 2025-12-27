{primary_device, ...}: {
  disko.devices = {
    disk = {
      primary = {
        device = primary_device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              type = "EF02"; # grub mbr
              size = "1M";
              attributes = [0];
            };
            main = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "main_pool";
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      main_pool = {
        type = "lvm_vg";
        lvs = {
          system = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = ["-f"]; # override existing
              subvolumes = let
                mk_subvol = {
                  mountpoint,
                  mountOptions ? [
                    "compress=zstd:1"
                    "noatime"
                  ],
                }: {
                  inherit mountpoint;
                  inherit mountOptions;
                };
              in {
                "@root" = mk_subvol "/" [];
                "@nix" = mk_subvol "/nix";
                "@logs" = mk_subvol "/var/logs";
                "@home" = mk_subvol "/home";
                "@swap" = {
                  mountpoint = "/.swapvol";
                  swap.swapfile.size = "10G";
                };
              };
            };
          };
        };
      };
    };
  };
}
