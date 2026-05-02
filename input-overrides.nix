let
  raw_source = source:
    source
    // {
      flake = false;
    }
    // (
      if source ? revision
      then {
        rev = source.revision;
        shortRev = builtins.substring 0 7 source.revision;
      }
      else {}
    );
in {
  nixpkgs.follows = "unstable";

  emacs-bleeding-edge.inputs.nixpkgs.follows = "nixpkgs";
  nur.inputs.nixpkgs.follows = "nixpkgs";
  hm.inputs.nixpkgs.follows = "nixpkgs";
  fup.inputs.flake-utils.follows = "flake-utils";
  flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  flake-utils.inputs.systems.follows = "all-systems";
  blueprint.inputs = {
    nixpkgs.follows = "nixpkgs";
    systems.follows = "all-systems";
  };
  devshell.inputs.nixpkgs.follows = "nixpkgs";
  pre-commit-hooks.inputs = {
    nixpkgs.follows = "nixpkgs";
    gitignore.follows = "gitignore";
  };
  gitignore.inputs.nixpkgs.follows = "nixpkgs";
  disko.inputs.nixpkgs.follows = "nixpkgs";
  deploy-rs.inputs = {
    nixpkgs.follows = "nixpkgs";
    utils.follows = "flake-utils";
  };
  sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  microvm.inputs.nixpkgs.follows = "nixpkgs";
  treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  optnix.inputs.nixpkgs.follows = "nixpkgs";
  musnix.inputs.nixpkgs.follows = "nixpkgs";
  zjstatus.inputs.nixpkgs.follows = "nixpkgs";
  nixcord.inputs.nixpkgs.follows = "nixpkgs";
  hyprland-plugins.inputs.nixpkgs.follows = "nixpkgs";
  niri.inputs = {
    nixpkgs.follows = "nixpkgs";
    nixpkgs-stable.follows = "nixpkgs";
  };
  hexecute.inputs.nixpkgs.follows = "nixpkgs";
  whisper-overlay.inputs = {
    nixpkgs.follows = "nixpkgs";
    devshell.follows = "devshell";
    flake-parts.follows = "flake-parts";
    pre-commit-hooks.follows = "pre-commit-hooks";
  };
  fenix.inputs.nixpkgs.follows = "nixpkgs";
  nixos-dns.inputs = {
    nixpkgs.follows = "nixpkgs";
    treefmt-nix.follows = "treefmt-nix";
  };
  hister.inputs.nixpkgs.follows = "nixpkgs";
  atticd.inputs = {
    nixpkgs.follows = "nixpkgs";
    flake-parts.follows = "flake-parts";
  };
  nixarr.inputs = {
    nixpkgs.follows = "nixpkgs";
    treefmt-nix.follows = "treefmt-nix";
    vpnconfinement.follows = "vpnconfinement";
  };
  llm-agents.inputs = {
    nixpkgs.follows = "nixpkgs";
    treefmt-nix.follows = "treefmt-nix";
    systems.follows = "all-systems";
    blueprint.follows = "blueprint";
    flake-parts.follows = "flake-parts";
  };

  mysecrets = raw_source;
  octodns-pihole-src = raw_source;
  pihole6api-src = raw_source;
  kaneo-src = raw_source;
  anthropic-skills = raw_source;
  superpowers = raw_source;
}
