{mylib, ...}: {
  imports = [
    ../_bootstrap/desktop.nix
    (mylib.hosts.host_config "lavpc")
  ];

  my = {
    host.title_file = ./assets/title.txt;
  };

  users = {
    groups.plugdev = {};
    users.lav.extraGroups = ["plugdev"];
  };

  # zram
  # zramSwap.enable = true;
  # boot.tmp.useZram = true;

  # Services
  services = {
    udev.extraRules = ''
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="31e3", ATTRS{idProduct}=="1402", GROUP="plugdev", MODE="0660"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3710", ATTRS{idProduct}=="5406", GROUP="plugdev", MODE="0660"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="36a7", ATTRS{idProduct}=="a882", GROUP="plugdev", MODE="0660"
    '';
  };

  # Virtualisation Support
  virtualisation.docker.storageDriver = "btrfs";
}
