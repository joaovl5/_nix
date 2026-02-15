{self, ...}: let
  DEFAULT_SYSTEM = "x86_64-linux";
in {
  #   packages.x86_64-linux.build_iso =
  #     self.nixosConfigurations.iso.config.system.build.isoImage;
  packages.${DEFAULT_SYSTEM} = {
    build_iso = let
      inherit (self.nixosConfigurations) iso;
    in
      iso.config.system.build.isoImage;
  };
}
