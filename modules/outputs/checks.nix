{
  globals,
  inputs,
  self,
  ...
}: let
  inherit (inputs) deploy-rs nixpkgs;
  each_supported_system = f:
    nixpkgs.lib.genAttrs
    ["x86_64-linux"]
    (system:
      f nixpkgs.legacyPackages.${system});
in {
  flake.checks = each_supported_system (
    pkgs: let
      extra_args = self._utils.hosts.mk_extra_args {inherit pkgs;};
      deploy_checks =
        if builtins.hasAttr pkgs.system deploy-rs.lib
        then deploy-rs.lib.${pkgs.system}.deployChecks self.deploy
        else {};
      test_checks = import ../../tests (extra_args
        // {
          inherit self pkgs;
          inherit (pkgs) lib;
        });
      backup_checks = import ../../lib/outputs/backups-checks.nix {
        inherit globals self pkgs;
        inherit (nixpkgs) lib;
      };
      deploy_contract_checks = import ../../lib/outputs/deploy-checks.nix {
        inherit self pkgs;
      };
    in
      backup_checks
      // test_checks
      // deploy_contract_checks
      // deploy_checks
  );
}
