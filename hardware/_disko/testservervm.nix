{
  primary_device, # nvme ssd
  ...
}: let
  inherit (import ../../_lib/disko.nix) efi luks btrfs;
  inherit (btrfs) subvolume;
in {
  disko.devices.disk.primary = {
    device = primary_device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        esp = efi {};
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
