check:
    just fmt
    ruff check . --quiet --no-cache
    basedpyright
    statix check -o errfmt -i **/emacs/config/**.nix
    nix flake check --quiet --log-format raw

fmt:
    nix fmt --quiet --log-format raw -- --no-cache
    deadnix -_ -L --edit --exclude **/emacs/config/**.nix

ci:
    nix fmt --quiet --log-format raw -- --ci
