{
  primary_device, # nvme ssd
  ...
}: let
  inherit (import ../../_lib/disko.nix) mbr luks btrfs;
  inherit (btrfs) subvolume;
in {
  disko.devices.disk.primary = {
    device = primary_device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        boot = mbr {};
        root = {
          size = "100%";
          content = {
            type = "lvm_pv";
            vg = "main_pool";
          };
        };
        # luks_p1 = luks {name = "p1";} {
        #   type = "btrfs";
        #   subvolumes = {
        #     "@root" = subvolume {mp = "/";};
        #   };
        # };
      };
    };
  };
  disko.devices.lvm_vg.main_pool = {
    type = "lvm_vg";
    lvs.system = {
      size = "100%";
      content = {
        type = "btrfs";
        subvolumes = {
          "@root" = subvolume {mp = "/";};
        };
      };
    };
  };
}
