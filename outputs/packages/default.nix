{self, ...} @ inputs: let
  DEFAULT_SYSTEM = "x86_64-linux";
  octodns = import ./octodns.nix inputs;
in {
  packages.${DEFAULT_SYSTEM} =
    {
      build_iso = let
        inherit (self.nixosConfigurations) iso;
      in
        iso.config.system.build.isoImage;
    }
    // octodns;
}
