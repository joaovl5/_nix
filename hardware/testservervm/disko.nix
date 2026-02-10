let
  params = {primary_device = "/dev/sda";};
  disko_cfg = ../_disko/testservervm.nix;
in
  import disko_cfg params
