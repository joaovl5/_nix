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
    nixpkgs.lib.recursiveUpdate
    (each_system (
      pkgs:
        {
          formatting = treefmt_eval.${pkgs.system}.config.build.check self;
        }
        // (import ./backups.nix {
          inherit self pkgs;
          inherit (nixpkgs) lib;
        })
    ))
    (builtins.mapAttrs
      (_system: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib);
}
