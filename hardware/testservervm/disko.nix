let
  params = {primary_device = "/dev/vda";};
  disko_cfg = ../_disko/testvm_btrfs.nix;
in
  import disko_cfg params
