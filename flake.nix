{
  description = "lav nixos config";

  inputs = {
    # ---------------
    # nixpkgs
    # ---------------
    stable.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-25.11&shallow=1";
    unstable.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-unstable&shallow=1";
    nixpkgs.follows = "unstable";
    nur = {
      url = "git+https://github.com/nix-community/NUR?shallow=1";
      inputs.nixpkgs.follows = "unstable";
    };
    # ---------------
    # core
    # ---------------
    ## home manager
    hm = {
      url = "git+https://github.com/nix-community/home-manager?shallow=1";
      inputs.nixpkgs.follows = "unstable";
    };
    ## flake utils lib
    fup.url = "git+https://github.com/gytis-ivaskevicius/flake-utils-plus?shallow=1";
    ## disko
    disko = {
      url = "git+https://github.com/nix-community/disko?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## deployment
    deploy-rs.url = "git+https://github.com/serokell/deploy-rs?shallow=1";
    ## secrets management
    sops-nix = {
      url = "git+https://github.com/Mic92/sops-nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## private secrets repository
    mysecrets = {
      url = "git+ssh://git@github.com/joaovl5/__secrets.git?ref=main&shallow=1";
      flake = false;
    };
    #### quality-of-life
    ## treefmt
    treefmt-nix = {
      url = "git+ssh://git@github.com/numtide/treefmt-nix.git?shallow=1";
    };
    ## all nix systems
    all-systems = {
      url = "git+ssh://git@github.com/nix-systems/default.git?shallow=1";
    };

    # ---------------
    # pkgs
    # ---------------
    # Desktop ---

    ## discord
    nixcord = {
      url = "git+https://github.com/FlameFlag/nixcord?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## hyprland
    hyprland-plugins = {
      url = "git+https://github.com/hyprwm/hyprland-plugins?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## niri
    niri = {
      url = "git+https://github.com/sodiboo/niri-flake?shallow=1";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs";
      };
    };
    ## zen browser
    zen-browser = {
      url = "git+https://github.com/0xc000022070/zen-browser-flake?shallow=1";
      inputs.nixpkgs.follows = "unstable";
      inputs.home-manager.follows = "hm";
    };
    firefox-addons = {
      ## support for declarative extensions
      url = "git+https://gitlab.com/rycee/nur-expressions?dir=pkgs/firefox-addons&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## rust nightly support
    fenix = {
      url = "git+https://github.com/nix-community/fenix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## flatpak support
    nix-flatpak = {
      url = "git+https://github.com/gmodena/nix-flatpak/?ref=v0.6.0&shallow=1";
    };
    # Server ---
    # dns
    nixos-dns = {
      url = "git+https://github.com/Janik-Haag/nixos-dns?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # atticd nix cache server thingy
    atticd = {
      url = "git+https://github.com/zhaofengli/attic?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -arr programs
    nixarr = {
      url = "git+https://github.com/nix-media-server/nixarr?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # my soularr fork with a nix flake - TODO: put in my nur repo
    soularr.url = "git+https://github.com/joaovl5/soularr.git?shallow=1";
    # Other ---
    ## ai
    anthropic-skills.url = "git+https://github.com/anthropics/skills?shallow=1";
    anthropic-skills.flake = false;
  };

  outputs = {fup, ...} @ inputs:
    fup.lib.mkFlake (import ./outputs inputs);
}
