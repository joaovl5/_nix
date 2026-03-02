{pkgs, ...}: {
  nixpkgs.overlays = [
    (_final: prev: {
      inherit
        (prev.lixPackageSets.stable)
        nix-eval-jobs
        nix-fast-build
        # nix-direnv
        nix-update
        # nix-serve-ng
        colmena
        # editline
        ;
    })
  ];

  nix.package = pkgs.lixPackageSets.stable.lix;
}
