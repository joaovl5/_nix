{
  pkgs,
  inputs,
  ...
}: let
  beads-ui = pkgs.callPackage ./beads-ui {inherit inputs;};
  beads-web = pkgs.callPackage ./beads-web {};
  degoog = pkgs.callPackage ./degoog {inherit inputs;};
  frag = pkgs.callPackage ./frag {inherit inputs;};
  gopeed-web = pkgs.callPackage ./gopeed-web {};
  lidarr-plugins = pkgs.callPackage ./lidarr-plugins {};
  kaneo = pkgs.callPackage ./kaneo {inherit inputs;};
  mardi-gras = pkgs.callPackage ./mardi-gras {inherit inputs;};
  pihole6api = pkgs.callPackage ./pihole6api {inherit inputs;};
  octodns-pihole = pkgs.callPackage ./octodns-pihole {
    inherit inputs pihole6api;
  };
  rumdl = pkgs.callPackage ./rumdl {inherit inputs;};
  sane_fnlfmt = pkgs.callPackage ./sane_fnlfmt {inherit inputs;};
  tubifarry = pkgs.callPackage ./tubifarry {};
  vm_launcher = pkgs.callPackage ./vm-launcher {};
in {
  inherit
    beads-ui
    beads-web
    degoog
    frag
    gopeed-web
    lidarr-plugins
    kaneo
    mardi-gras
    pihole6api
    octodns-pihole
    rumdl
    sane_fnlfmt
    tubifarry
    vm_launcher
    ;
}
