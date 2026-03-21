{self, ...}: let
  DEFAULT_SYSTEM = "x86_64-linux";
in {
  apps.${DEFAULT_SYSTEM}.vm = {
    type = "app";
    program = "${self.packages.${DEFAULT_SYSTEM}.vm_launcher}/bin/vm-launcher";
  };
}
