{self, ...} @ inputs: let
  DEFAULT_SYSTEM = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${DEFAULT_SYSTEM};
  octodns = import ./octodns.nix inputs;
  vm_launcher = import ./vm.nix {inherit pkgs;};
in {
  packages.${DEFAULT_SYSTEM} =
    {
      build_iso = let
        inherit (self.nixosConfigurations) iso;
      in
        iso.config.system.build.isoImage;
      inherit vm_launcher;
    }
    // octodns;
}
