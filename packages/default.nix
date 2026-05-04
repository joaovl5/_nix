{
  pkgs,
  inputs,
  ...
}: let
  degoog = pkgs.callPackage ./degoog {inherit inputs;};
  frag = pkgs.callPackage ./frag {inherit inputs;};
  kaneo = pkgs.callPackage ./kaneo {inherit inputs;};
  pihole6api = pkgs.callPackage ./pihole6api {inherit inputs;};
  octodns-pihole = pkgs.callPackage ./octodns-pihole {
    inherit inputs pihole6api;
  };
  vm_launcher = pkgs.callPackage ./vm-launcher {};
in {
  inherit degoog frag kaneo pihole6api octodns-pihole vm_launcher;
}
