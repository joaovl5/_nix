{
  pkgs,
  inputs,
  ...
}: let
  beads-ui = pkgs.callPackage ./beads-ui {inherit inputs;};
  beads-web = pkgs.callPackage ./beads-web {};
  degoog = pkgs.callPackage ./degoog {inherit inputs;};
  frag = pkgs.callPackage ./frag {inherit inputs;};
  kaneo = pkgs.callPackage ./kaneo {inherit inputs;};
  mardi-gras = pkgs.callPackage ./mardi-gras {inherit inputs;};
  pihole6api = pkgs.callPackage ./pihole6api {inherit inputs;};
  octodns-pihole = pkgs.callPackage ./octodns-pihole {
    inherit inputs pihole6api;
  };
  rumdl = pkgs.callPackage ./rumdl {inherit inputs;};
  sane_fnlfmt = pkgs.callPackage ./sane_fnlfmt {inherit inputs;};
  vm_launcher = pkgs.callPackage ./vm-launcher {};
in {
  inherit
    beads-ui
    beads-web
    degoog
    frag
    kaneo
    mardi-gras
    pihole6api
    octodns-pihole
    rumdl
    sane_fnlfmt
    vm_launcher
    ;
}
