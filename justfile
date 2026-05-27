nix_raw := "nix --quiet --log-format raw"
nix_build := nix_raw + " build --no-link --file . "
rumdl := nix_raw + " run '.#rumdl' --"

ruff := "ruff --quiet"

basedpyright := "basedpyright --warnings"

# exclude emacs straight.el pkgs that have .nix files
emacs_vendored_nix := "**/emacs/config/**.nix"

check: fmt
    _scripts/checks.fish

fmt:
    _scripts/format.fish

deploy: check
    deploy --skip-checks
