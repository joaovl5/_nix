#!/run/current-system/sw/bin/env fish

nh clean all -e run0
nix store optimise
