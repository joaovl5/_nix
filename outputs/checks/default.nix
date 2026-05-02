{
  globals,
  inputs,
}: let
  inherit (inputs) deploy-rs nixpkgs self;
  each_supported_system = f:
    nixpkgs.lib.genAttrs
    ["x86_64-linux"]
    (system:
      f nixpkgs.legacyPackages.${system});

  treefmt = import ./treefmt inputs;
in {
  formatter = treefmt.format;
  checks = each_supported_system (
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
      backup_checks = import ./backups.nix {
        inherit globals self pkgs;
        inherit (nixpkgs) lib;
      };
      formatting_checks = {
        formatting = treefmt.format_check pkgs;
      };
    in
      formatting_checks
      // backup_checks
      // test_checks
      // deploy_checks
  );
}
