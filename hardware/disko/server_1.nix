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
            root = {
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
                  mp,
                  opts ? [
                    "compress=zstd:1"
                    "noatime"
                  ],
                  extraOpts ? [],
                }: {
                  mountpoint = mp;
                  mountOptions = opts ++ extraOpts;
                };
              in {
                "@root" = mk_subvol {
                  mp = "/";
                  opts = [];
                };
                "@nix" = mk_subvol {mp = "/nix";};
                "@logs" = mk_subvol {mp = "/var/logs";};
                "@home" = mk_subvol {mp = "/home";};
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
