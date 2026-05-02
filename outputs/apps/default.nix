{inputs, ...}: let
  inherit (inputs) all-systems nixpkgs self;
  DEFAULT_SYSTEM = "x86_64-linux";

  each_system = f:
    nixpkgs.lib.genAttrs
    (import all-systems)
    (system:
      f nixpkgs.legacyPackages.${system});

  treefmt = import ../checks/treefmt inputs;
in {
  apps =
    {
      ${DEFAULT_SYSTEM}.vm = {
        type = "app";
        program = "${self.packages.${DEFAULT_SYSTEM}.vm_launcher}/bin/vm-launcher";
      };
    }
    // (each_system (pkgs: {
      format = {
        type = "app";
        program = "${treefmt.format_wrapper pkgs}/bin/treefmt";
      };
    }));
}
