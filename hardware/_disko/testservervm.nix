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
        luks_p1 = luks {name = "p1";} {
          type = "btrfs";
          subvolumes = {
            "@root" = subvolume {mp = "/";};
          };
        };
      };
    };
  };
}
