{den, inputs, self, ...}: {
  den.aspects.system-essos = {

    darwin = {
      pkgs,
      ...
    }: {
      nixpkgs.source = inputs.nixpkgs-unstable;
        nix.settings.experimental-features = "nix-command flakes";
          system.configurationRevision = self.rev or self.dirtyRev or null;

      system.stateVersion = 6;
      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  };
}
