{
  treefmt-nix,
  nixpkgs,
  all-systems,
  ...
}: let
  each_system = f:
    nixpkgs.lib.genAttrs
    (import all-systems)
    (system:
      f nixpkgs.legacyPackages.${system});

  treefmt_eval = each_system (pkgs: treefmt-nix.lib.evalModule pkgs ./config.nix);
  project_root = ../../..;
in {
  format = each_system (pkgs: treefmt_eval.${pkgs.system}.config.build.wrapper);
  format_check = pkgs: treefmt_eval.${pkgs.system}.config.build.check project_root;
  format_wrapper = pkgs: treefmt-nix.lib.mkWrapper pkgs ./config.nix;
}
