{
  pkgs,
  inputs,
  ...
}: let
  pihole6api = pkgs.callPackage ./pihole6api {inherit inputs;};
  octodns-pihole = pkgs.callPackage ./octodns-pihole {
    inherit inputs pihole6api;
  };
  vm_launcher = pkgs.callPackage ./vm-launcher {};
in {
  inherit pihole6api octodns-pihole vm_launcher;
}
