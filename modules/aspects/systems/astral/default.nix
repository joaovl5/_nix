{den, ...}: {
  den.aspects.system-astral = {
    includes = [den.aspects.system-desktop-base];

    nixos = {globals, ...}: {
      my = {
        host.title_file = ./assets/title.txt;
      };

      imports = [
        globals.hosts.lavpc.config
      ];

      users = {
        groups.plugdev = {};
        users.lav.extraGroups = ["plugdev"];
      };

      # zram
      # zramSwap.enable = true;
      # boot.tmp.useZram = true;

      # Services
      services = {
        envfs = {
          # fixes /usr/bin stuff
          enable = true;
        };
        udev.extraRules = ''
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="31e3", ATTRS{idProduct}=="1402", GROUP="plugdev", MODE="0660"
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3710", ATTRS{idProduct}=="5406", GROUP="plugdev", MODE="0660"
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="36a7", ATTRS{idProduct}=="a882", GROUP="plugdev", MODE="0660"
        '';
      };

      # Virtualisation Support
      virtualisation.docker.storageDriver = "btrfs";
    };
  };
}
