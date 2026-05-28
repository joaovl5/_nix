{self, ...}: let
  system = "x86_64-linux";
in {
  flake.apps.${system}.vm = {
    type = "app";
    program = "${self.packages.${system}.vm_launcher}/bin/vm-launcher";
  };
}
