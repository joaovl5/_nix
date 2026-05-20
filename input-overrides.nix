let
  git_release_commit_revisions = {
    # npins stores annotated tag object IDs for GitRelease pins, but flake-like
    # consumers such as niri-flake expect the peeled commit revision in `rev`.
    "d85b524d7c07a47345eab434f471f2b7bfa2c9c3" = "01be0e65f4eb91a9cd624ac0b76aaeab765c7294";
    "838e68b9ef35613524b0a76a569afdaab7d5ce8c" = "388d291e82ffbc73be18169d39470f340707edaa";
  };
  raw_source = source:
    source
    // {
      flake = false;
    }
    // (
      if source ? revision
      then let
        rev = git_release_commit_revisions.${source.revision} or source.revision;
      in {
        inherit rev;
        shortRev = builtins.substring 0 7 rev;
      }
      else {}
    );
in {
  nixpkgs.follows = "unstable";

  # We quote some keys to avoid linters warnings of multiple key definitions
  # keep-sorted start
  "bun2nix".inputs.flake-parts.follows = "flake-parts";
  "bun2nix".inputs.nixpkgs.follows = "nixpkgs";
  "bun2nix".inputs.systems.follows = "all-systems";
  "bun2nix".inputs.treefmt-nix.follows = "treefmt-nix";
  "hermes-agent".inputs.flake-parts.follows = "flake-parts";
  "hermes-agent".inputs.nixpkgs.follows = "nixpkgs";
  "hermes-agent".inputs.npm-lockfile-fix.follows = "npm-lockfile-fix";
  "hermes-agent".inputs.pyproject-build-systems.follows = "pyproject-build-systems";
  "hermes-agent".inputs.pyproject-nix.follows = "pyproject-nix";
  "hermes-agent".inputs.uv2nix.follows = "uv2nix";
  "llm-agents".inputs.blueprint.follows = "blueprint";
  "llm-agents".inputs.bun2nix.follows = "bun2nix";
  "llm-agents".inputs.flake-parts.follows = "flake-parts";
  "llm-agents".inputs.nixpkgs.follows = "nixpkgs";
  "llm-agents".inputs.systems.follows = "all-systems";
  "llm-agents".inputs.treefmt-nix.follows = "treefmt-nix";
  "niri".inputs.niri-stable.follows = "niri-stable";
  "niri".inputs.niri-unstable.follows = "niri-unstable";
  "niri".inputs.nixpkgs-stable.follows = "nixpkgs";
  "niri".inputs.nixpkgs.follows = "nixpkgs";
  "niri".inputs.xwayland-satellite-stable.follows = "xwayland-satellite-stable";
  "niri".inputs.xwayland-satellite-unstable.follows = "xwayland-satellite-unstable";
  "nixarr".inputs.nixpkgs.follows = "nixpkgs";
  "nixarr".inputs.treefmt-nix.follows = "treefmt-nix";
  "nixarr".inputs.vpnconfinement.follows = "vpnconfinement";
  "nixcord".inputs.flake-parts.follows = "flake-parts";
  "nixcord".inputs.nixpkgs-nixcord.follows = "stable";
  "nixcord".inputs.nixpkgs.follows = "nixpkgs";
  "pyproject-build-systems".inputs.nixpkgs.follows = "nixpkgs";
  "pyproject-build-systems".inputs.pyproject-nix.follows = "pyproject-nix";
  "pyproject-build-systems".inputs.uv2nix.follows = "uv2nix";
  "whisper-overlay".inputs.devshell.follows = "devshell";
  "whisper-overlay".inputs.flake-parts.follows = "flake-parts";
  "whisper-overlay".inputs.nixpkgs.follows = "nixpkgs";
  "whisper-overlay".inputs.pre-commit-hooks.follows = "pre-commit-hooks";
  "zjstatus".inputs.crane.follows = "crane";
  "zjstatus".inputs.flake-utils.follows = "flake-utils";
  "zjstatus".inputs.nixpkgs.follows = "nixpkgs";
  "zjstatus".inputs.rust-overlay.follows = "rust-overlay";
  anthropic-skills = raw_source;
  atticd.inputs.flake-parts.follows = "flake-parts";
  atticd.inputs.nixpkgs.follows = "nixpkgs";
  blueprint.inputs.nixpkgs.follows = "nixpkgs";
  blueprint.inputs.systems.follows = "all-systems";
  degoog-src = raw_source;
  deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  deploy-rs.inputs.utils.follows = "flake-utils";
  devshell.inputs.nixpkgs.follows = "nixpkgs";
  disko.inputs.nixpkgs.follows = "nixpkgs";
  emacs-bleeding-edge.inputs.nixpkgs.follows = "nixpkgs";
  fenix.inputs.nixpkgs.follows = "nixpkgs";
  flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  flake-utils.inputs.systems.follows = "all-systems";
  fup.inputs.flake-utils.follows = "flake-utils";
  gitignore.inputs.nixpkgs.follows = "nixpkgs";
  hexecute.inputs.nixpkgs.follows = "nixpkgs";
  hister.inputs.nixpkgs.follows = "nixpkgs";
  hm.inputs.nixpkgs.follows = "nixpkgs";
  hyprland-plugins.inputs.nixpkgs.follows = "nixpkgs";
  jandent-src = raw_source;
  janet-nix.inputs.nixpkgs.follows = "nixpkgs";
  jcode.inputs.nixpkgs.follows = "nixpkgs";
  kaneo-src = raw_source;
  microvm.inputs.nixpkgs.follows = "nixpkgs";
  musnix.inputs.nixpkgs.follows = "nixpkgs";
  mysecrets = raw_source;
  niri-stable = raw_source;
  niri-unstable = raw_source;
  nixos-dns.inputs.nixpkgs.follows = "nixpkgs";
  nixos-dns.inputs.treefmt-nix.follows = "treefmt-nix";
  npm-lockfile-fix.inputs.nixpkgs.follows = "nixpkgs";
  nur.inputs.nixpkgs.follows = "nixpkgs";
  octodns-pihole-src = raw_source;
  optnix.inputs.nixpkgs.follows = "nixpkgs";
  pihole6api-src = raw_source;
  pre-commit-hooks.inputs.gitignore.follows = "gitignore";
  pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
  pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";
  rumdl-src = raw_source;
  rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  superpowers = raw_source;
  treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  uv2nix.inputs.nixpkgs.follows = "nixpkgs";
  uv2nix.inputs.pyproject-nix.follows = "pyproject-nix";
  xwayland-satellite-stable = raw_source;
  xwayland-satellite-unstable = raw_source;
  # keep-sorted end
}
