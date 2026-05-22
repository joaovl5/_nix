nix_raw := "nix --quiet --log-format raw"
rumdl := nix_raw + " run '.#rumdl' --"

ruff := "ruff --quiet"

basedpyright := "basedpyright --warnings"

# exclude emacs straight.el pkgs that have .nix files
emacs_vendored_nix := "**/emacs/config/**.nix"

[script("fish")]
check: fmt
    statix check \
        -o errfmt \
        -i {{ emacs_vendored_nix }}
    {{ rumdl }} check \
        --no-cache \
        --silent \
        --fail-on warning \
        --output-format concise
    {{ ruff }} check \
        --no-cache
    {{ basedpyright }}
    {{ nix_raw }} flake check

fmt:
    echo "..."

[script("fish")]
deploy: check
    deploy --skip-checks
