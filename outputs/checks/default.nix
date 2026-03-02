{
  self,
  deploy-rs,
  treefmt-nix,
  all-systems,
  nixpkgs,
  ...
}: let
  each_system = f:
    nixpkgs.lib.genAttrs
    (import all-systems)
    (system:
      f nixpkgs.legacyPackages.${system});

  treefmt_eval = each_system (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
in {
  formatter = each_system (pkgs: treefmt_eval.${pkgs.system}.config.build.wrapper);
  checks =
    (each_system (
      pkgs: {
        formatting = treefmt_eval.${pkgs.system}.config.build.check self;
      }
    ))
    // (builtins.mapAttrs
      (_system: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib)
    // (each_system (pkgs: {
      test_vm = pkgs.testers.runNixOSTest (
        import ../../tests/vm
        (
          {
            inherit
              pkgs
              self
              ;
          }
          // (
            self._utils.hosts.mk_extra_args {
              inherit pkgs;
            }
          )
        )
      );
    }));
}
