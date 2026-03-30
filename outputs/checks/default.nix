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
  checks = each_system (
    pkgs: let
      extraArgs = self._utils.hosts.mk_extra_args {inherit pkgs;};
      deployChecks =
        if builtins.hasAttr pkgs.system deploy-rs.lib
        then deploy-rs.lib.${pkgs.system}.deployChecks self.deploy
        else {};
      testChecks = import ../../tests (extraArgs
        // {
          inherit self pkgs;
          inherit (pkgs) lib;
        });
    in
      {
        formatting = treefmt_eval.${pkgs.system}.config.build.check self;
      }
      // testChecks
      // deployChecks
  );
}
