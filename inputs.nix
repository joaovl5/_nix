let
  sources = builtins.removeAttrs (import ./npins) ["__functor"];
  flake_compat = import sources.flake-compat;

  raw_inputs = [
    "all-systems"
    "degoog-src"
    "fennel-ls-nvim-docs"
    "flake-compat"
    "kaneo-src"
    "mardi-gras-src"
    "mysecrets"
    "nix-machine-protocol-src"
    "octodns-pihole-src"
    "pihole6api-src"
    "rumdl-src"
    "sane-fnlfmt-src"
    "superpowers"
    "tree-sitter-kanata"
  ];

  normalize_source = source:
    if !(builtins.isAttrs source)
    then source
    else let
      rev = source.rev or source.revision or null;
    in
      source
      // (
        if rev != null && !(source ? rev)
        then {inherit rev;}
        else {}
      )
      // (
        if rev != null && !(source ? shortRev)
        then {shortRev = builtins.substring 0 7 rev;}
        else {}
      );

  load_flake = source: (flake_compat {src = source;}).outputs;

  load_input = name: source:
    normalize_source (
      if builtins.elem name raw_inputs
      then source
      else load_flake source
    );

  inputs = builtins.mapAttrs load_input sources;
in
  inputs
  // {
    home-manager = inputs.hm;
    nixpkgs = inputs.unstable;
  }
