{lib, ...}: {
  projectRootFile = "npins/sources.json";
  programs = {
    keep-sorted.enable = true;

    # nix
    alejandra.enable = true;
    deadnix.enable = true;
    statix.enable = true;
    # fennel
    fnlfmt.enable = true;
    # python
    ruff-format.enable = true;
    # js
    biome = {
      enable = true;
      formatCommand = "format";
    };
    # fish and sh
    fish_indent.enable = true;
    shfmt.enable = true;
    # lua
    stylua.enable = true;
    # toml and friends
    taplo.enable = true;
    jsonfmt.enable = true;
    # others
    kdlfmt = {
      enable = true;
    };
    just.enable = true;
    sqruff.enable = true;
  };
  settings.formatter.kdlfmt.options = lib.mkForce [
    "format"
    "--kdl-version"
    "v1"
  ];

  settings.formatter.biome.options = lib.mkForce [
    "format"
    "--write"
    "--no-errors-on-unmatched"
    "--config-path=biome.json"
    "--skip-parse-errors"
    "--diagnostic-level=warn"
  ];
}
