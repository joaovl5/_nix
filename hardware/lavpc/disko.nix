let
  params = {
    dev_1 = "/dev/nvme0n1";
    dev_2 = "/dev/sda";
    dev_3 = "/dev/sdb";
  };
  disko_cfg = ../_disko/lavpc_v2.nix;
in
  _: (import disko_cfg params)
