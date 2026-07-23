{
  pkgs,
  inputs,
  ...
}: let
  ashrwm = pkgs.callPackage ./ashrwm {inherit inputs;};
  beads-ui = pkgs.callPackage ./beads-ui {inherit inputs;};
  beads-web = pkgs.callPackage ./beads-web {};
  degoog = pkgs.callPackage ./degoog {inherit inputs;};
  llm_agents = pkgs.callPackage ./llm-agents {inherit inputs;};
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
in {
  inherit
    ashrwm
    beads-ui
    beads-web
    degoog
    gopeed-web
    lidarr-plugins
    kaneo
    llm_agents
    mardi-gras
    pihole6api
    octodns-pihole
    rumdl
    sane_fnlfmt
    tubifarry
    ;
}
