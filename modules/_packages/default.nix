{
  pkgs,
  inputs,
  ...
}: let
  ashrwm = pkgs.callPackage ./ashrwm {inherit inputs;};
  llm_agents = pkgs.callPackage ./llm-agents {inherit inputs;};
  gopeed-web = pkgs.callPackage ./gopeed-web {};
  lidarr-plugins = pkgs.callPackage ./lidarr-plugins {};
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
    gopeed-web
    lidarr-plugins
    llm_agents
    pihole6api
    octodns-pihole
    rumdl
    sane_fnlfmt
    tubifarry
    ;
}
