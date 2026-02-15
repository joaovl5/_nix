let
  params = {primary_device = "/dev/sda";};
  disko_cfg = ../_disko/server_1.nix;
in
  _: (
    import disko_cfg params
    // {
      boot.loader.grub.enable = false;
      boot.loader.limine = {
        enable = true;
        biosDevice = params.primary_device;
        force = true;
        efiSupport = false;
      };
    }
  )
