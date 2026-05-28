{den, ...}: {
  den.aspects.system-iso = {
    includes = [den.aspects.system-minimal-base];

    nixos = {
      lib,
      modulesPath,
      ...
    }: {
      imports = [
        (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
        {my_system.title = lib.readFile ./assets/title.txt;}
      ];
      my.nix.hostname = "my_iso";

      isoImage.squashfsCompression = "gzip -Xcompression-level 1";
    };
  };
}
