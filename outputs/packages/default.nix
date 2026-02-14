{self, ...}: let
  DEFAULT_SYSTEM = "x86_64-linux";
in {
  packages.${DEFAULT_SYSTEM} = {
    build_iso = let
      inherit (self.nixosConfigurations) iso;
    in
      iso.config.system.build.isoImage;
  };
}
