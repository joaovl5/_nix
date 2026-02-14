let
  params = {primary_device = "/dev/sda";};
  disko_cfg = ../_disko/testservervm.nix;
in
  _: (
    import disko_cfg params
    // {
      boot.loader.grub.enable = false;
      boot.loader.limine = {
        enable = true;
        biosDevice = params.primary_device;
        forceMbr = true;
        efiSupport = false;
      };
      # boot.loader.systemd-boot = {
      #   enable = true;
      # };
      # boot.loader.grub = assert (
      #   params.primary_device != null && params.primary_device != ""
      # ); {
      #   device = lib.mkForce params.primary_device;
      #   devices = lib.mkForce [params.primary_device];
      #   mirroredBoots = lib.mkForce [
      #     {
      #       devices = ["/dev/sda1"];
      #       path = "/boot";
      #     }
      #   ];
      # };
    }
  )
